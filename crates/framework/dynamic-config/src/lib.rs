use std::{env, path::PathBuf, sync::Arc, time::Duration};

use anyhow::{Context, anyhow};
use nacos_sdk::api::{
    config::{ConfigChangeListener, ConfigResponse, ConfigService, ConfigServiceBuilder},
    error::Error as NacosError,
    props::ClientProps,
};
use serde::{Deserialize, Serialize, de::DeserializeOwned};
use tokio::{sync::watch, time::timeout};
use tracing::{error, info, warn};

const DEFAULT_GROUP: &str = "RUST_TOON";
const DEFAULT_CACHE_DIR: &str = "/tmp/rust-toon-nacos-cache";
const DEFAULT_CONNECT_TIMEOUT_SECONDS: u64 = 15;
const MAX_CONFIG_BYTES: usize = 64 * 1024;
const FIRST_PUBLICATION_POLL_INTERVAL: Duration = Duration::from_secs(5);

type Validator<T> = Arc<dyn Fn(&T) -> anyhow::Result<()> + Send + Sync>;

/// Connection and subscription settings shared by all Rust services.
///
/// r-nacos is deliberately used only for non-secret runtime configuration.
/// Credentials remain environment/Secret inputs and are never read from the
/// dynamic document itself.
#[derive(Clone)]
pub struct NacosConfig {
    pub enabled: bool,
    pub required: bool,
    pub server_addr: String,
    pub namespace: String,
    pub group: String,
    pub data_id: String,
    pub app_name: String,
    pub username: Option<String>,
    password: Option<String>,
    pub cache_dir: PathBuf,
    pub connect_timeout: Duration,
}

impl NacosConfig {
    pub fn from_env(service_name: &str) -> anyhow::Result<Self> {
        let server_addr = non_empty_env("NACOS_SERVER_ADDR").unwrap_or_default();
        let enabled = env_bool("NACOS_ENABLED", !server_addr.is_empty())?;
        let required = env_bool("NACOS_REQUIRED", false)?;
        anyhow::ensure!(
            !enabled || !server_addr.is_empty(),
            "NACOS_SERVER_ADDR is required when NACOS_ENABLED=true"
        );
        anyhow::ensure!(
            !required || enabled,
            "NACOS_ENABLED must be true when NACOS_REQUIRED=true"
        );

        let username = non_empty_env("NACOS_USERNAME");
        let password = non_empty_env("NACOS_PASSWORD");
        anyhow::ensure!(
            username.is_some() == password.is_some(),
            "NACOS_USERNAME and NACOS_PASSWORD must be set together"
        );

        Ok(Self {
            enabled,
            required,
            server_addr,
            namespace: env::var("NACOS_NAMESPACE").unwrap_or_default(),
            group: non_empty_env("NACOS_GROUP").unwrap_or_else(|| DEFAULT_GROUP.into()),
            data_id: non_empty_env("NACOS_DATA_ID")
                .unwrap_or_else(|| format!("rust-toon-{service_name}.json")),
            app_name: format!("rust-toon-{service_name}"),
            username,
            password,
            cache_dir: PathBuf::from(
                non_empty_env("NACOS_CACHE_DIR").unwrap_or_else(|| DEFAULT_CACHE_DIR.into()),
            ),
            connect_timeout: Duration::from_secs(env_number(
                "NACOS_CONNECT_TIMEOUT_SECONDS",
                DEFAULT_CONNECT_TIMEOUT_SECONDS,
                1,
                120,
            )?),
        })
    }
}

/// Owns the SDK service/listener and exposes a cheap latest-value receiver.
/// Keep this value alive for as long as the service should receive updates.
pub struct DynamicConfig<T: Clone> {
    receiver: watch::Receiver<T>,
    _service: Option<ConfigService>,
    _listener: Option<Arc<dyn ConfigChangeListener>>,
    first_publication_task: Option<tokio::task::JoinHandle<()>>,
}

impl<T: Clone> DynamicConfig<T> {
    pub fn receiver(&self) -> watch::Receiver<T> {
        self.receiver.clone()
    }

    pub fn current(&self) -> T {
        self.receiver.borrow().clone()
    }
}

impl<T: Clone> Drop for DynamicConfig<T> {
    fn drop(&mut self) {
        if let Some(task) = self.first_publication_task.take() {
            task.abort();
        }
    }
}

/// Subscribe to a JSON configuration document and retain the last valid value.
///
/// Invalid pushes are rejected atomically. If r-nacos is optional and cannot be
/// reached during startup, the supplied environment-derived defaults are used.
pub async fn subscribe_json<T, F>(
    config: NacosConfig,
    defaults: T,
    validate: F,
) -> anyhow::Result<DynamicConfig<T>>
where
    T: Clone + DeserializeOwned + Send + Sync + 'static,
    F: Fn(&T) -> anyhow::Result<()> + Send + Sync + 'static,
{
    let validator: Validator<T> = Arc::new(validate);
    validator(&defaults).context("validate default dynamic configuration")?;
    let (sender, receiver) = watch::channel(defaults);

    if !config.enabled {
        info!(data_id = %config.data_id, "dynamic configuration is disabled");
        return Ok(DynamicConfig {
            receiver,
            _service: None,
            _listener: None,
            first_publication_task: None,
        });
    }

    let mut props = ClientProps::new()
        .server_addr(config.server_addr.clone())
        .namespace(config.namespace.clone())
        .app_name(config.app_name.clone())
        .config_load_cache_at_start(true)
        .cache_dir(config.cache_dir.clone())
        .env_first(false);
    if let (Some(username), Some(password)) = (&config.username, &config.password) {
        props = props
            .auth_username(username.clone())
            .auth_password(password.clone());
    }

    let mut builder = ConfigServiceBuilder::new(props);
    if config.username.is_some() {
        builder = builder.enable_auth_plugin_http();
    }
    let service = match timeout(config.connect_timeout, builder.build()).await {
        Ok(Ok(service)) => service,
        Ok(Err(error)) => {
            return startup_failure_or_defaults(config, receiver, error.into());
        }
        Err(_) => {
            return startup_failure_or_defaults(
                config,
                receiver,
                anyhow!("r-nacos client initialization timed out"),
            );
        }
    };

    let initial = timeout(
        config.connect_timeout,
        service.get_config(config.data_id.clone(), config.group.clone()),
    )
    .await;
    let mut wait_for_first_publication = false;
    match initial {
        Ok(Ok(response)) => match parse_and_validate(response.content(), &validator) {
            Ok(value) => {
                sender.send_replace(value);
                info!(
                    data_id = %config.data_id,
                    group = %config.group,
                    md5 = %response.md5(),
                    "initial dynamic configuration applied"
                );
            }
            Err(error) if config.required => {
                return Err(error).context("initial r-nacos configuration is invalid");
            }
            Err(error) => {
                warn!(
                    %error,
                    data_id = %config.data_id,
                    group = %config.group,
                    "invalid initial dynamic configuration rejected; using defaults"
                );
            }
        },
        Ok(Err(NacosError::ConfigNotFound(_))) => {
            wait_for_first_publication = true;
            warn!(
                data_id = %config.data_id,
                group = %config.group,
                "dynamic configuration does not exist yet; using defaults until it is published"
            );
        }
        Ok(Err(error)) if config.required => {
            return Err(error).context("load initial r-nacos configuration");
        }
        Ok(Err(error)) => {
            warn!(
                %error,
                data_id = %config.data_id,
                group = %config.group,
                "initial dynamic configuration unavailable; using defaults"
            );
        }
        Err(_) if config.required => {
            anyhow::bail!("loading initial r-nacos configuration timed out");
        }
        Err(_) => {
            warn!(
                data_id = %config.data_id,
                group = %config.group,
                "loading initial dynamic configuration timed out; using defaults"
            );
        }
    }

    let listener: Arc<dyn ConfigChangeListener> = Arc::new(JsonConfigListener {
        sender: sender.clone(),
        validator: validator.clone(),
    });
    let add_listener = timeout(
        config.connect_timeout,
        service.add_listener(
            config.data_id.clone(),
            config.group.clone(),
            listener.clone(),
        ),
    )
    .await;
    match add_listener {
        Ok(Ok(())) => info!(
            data_id = %config.data_id,
            group = %config.group,
            "r-nacos dynamic configuration listener started"
        ),
        Ok(Err(error)) if config.required => {
            return Err(error).context("register r-nacos configuration listener");
        }
        Err(_) if config.required => {
            anyhow::bail!("registering r-nacos configuration listener timed out");
        }
        Ok(Err(error)) => warn!(
            %error,
            data_id = %config.data_id,
            group = %config.group,
            "dynamic configuration listener unavailable; current value will remain active"
        ),
        Err(_) => warn!(
            data_id = %config.data_id,
            group = %config.group,
            "registering dynamic configuration listener timed out; current value will remain active"
        ),
    }

    // nacos-sdk intentionally suppresses the listener callback for the first
    // value used to initialize an empty local cache. If a document did not
    // exist at startup, briefly poll until its first publication so that a
    // create operation is just as hot as every later update.
    let first_publication_task = wait_for_first_publication.then(|| {
        tokio::spawn(wait_for_first_publication_task(
            service.clone(),
            config.data_id.clone(),
            config.group.clone(),
            config.connect_timeout,
            sender,
            validator,
        ))
    });

    Ok(DynamicConfig {
        receiver,
        _service: Some(service),
        _listener: Some(listener),
        first_publication_task,
    })
}

async fn wait_for_first_publication_task<T>(
    service: ConfigService,
    data_id: String,
    group: String,
    request_timeout: Duration,
    sender: watch::Sender<T>,
    validator: Validator<T>,
) where
    T: Clone + DeserializeOwned + Send + Sync + 'static,
{
    let mut tick = tokio::time::interval(FIRST_PUBLICATION_POLL_INTERVAL);
    tick.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
    loop {
        tick.tick().await;
        match timeout(
            request_timeout,
            service.get_config(data_id.clone(), group.clone()),
        )
        .await
        {
            Ok(Ok(response)) => match parse_and_validate(response.content(), &validator) {
                Ok(value) => {
                    sender.send_replace(value);
                    info!(
                        %data_id,
                        %group,
                        md5 = %response.md5(),
                        "first dynamic configuration publication applied"
                    );
                    return;
                }
                Err(error) => warn!(
                    %error,
                    %data_id,
                    %group,
                    "invalid first dynamic configuration publication rejected"
                ),
            },
            Ok(Err(NacosError::ConfigNotFound(_))) => {}
            Ok(Err(error)) => warn!(
                %error,
                %data_id,
                %group,
                "waiting for first dynamic configuration publication"
            ),
            Err(_) => warn!(
                %data_id,
                %group,
                "waiting for first dynamic configuration publication timed out"
            ),
        }
    }
}

fn startup_failure_or_defaults<T: Clone>(
    config: NacosConfig,
    receiver: watch::Receiver<T>,
    error: anyhow::Error,
) -> anyhow::Result<DynamicConfig<T>> {
    if config.required {
        return Err(error).context("initialize required r-nacos client");
    }
    warn!(
        %error,
        data_id = %config.data_id,
        "r-nacos unavailable at startup; using defaults until the next process restart"
    );
    Ok(DynamicConfig {
        receiver,
        _service: None,
        _listener: None,
        first_publication_task: None,
    })
}

struct JsonConfigListener<T: Clone> {
    sender: watch::Sender<T>,
    validator: Validator<T>,
}

impl<T> ConfigChangeListener for JsonConfigListener<T>
where
    T: Clone + DeserializeOwned + Send + Sync + 'static,
{
    fn notify(&self, response: ConfigResponse) {
        match parse_and_validate(response.content(), &self.validator) {
            Ok(value) => {
                self.sender.send_replace(value);
                info!(
                    data_id = %response.data_id(),
                    group = %response.group(),
                    md5 = %response.md5(),
                    "dynamic configuration update applied"
                );
            }
            Err(error) => error!(
                %error,
                data_id = %response.data_id(),
                group = %response.group(),
                md5 = %response.md5(),
                "invalid dynamic configuration update rejected; retaining last known good value"
            ),
        }
    }
}

fn parse_and_validate<T>(content: &str, validator: &Validator<T>) -> anyhow::Result<T>
where
    T: DeserializeOwned,
{
    anyhow::ensure!(
        content.len() <= MAX_CONFIG_BYTES,
        "dynamic configuration exceeds {MAX_CONFIG_BYTES} bytes"
    );
    let value = serde_json::from_str(content).context("parse dynamic configuration JSON")?;
    validator(&value)?;
    Ok(value)
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct GatewayRuntimeConfig {
    pub schema_version: u32,
    pub rate_limit: RateLimitRuntimeConfig,
}

impl GatewayRuntimeConfig {
    pub fn new(max_requests: u64, window_seconds: u64) -> Self {
        Self {
            schema_version: 1,
            rate_limit: RateLimitRuntimeConfig {
                max_requests,
                window_seconds,
            },
        }
    }

    pub fn validate(&self) -> anyhow::Result<()> {
        anyhow::ensure!(self.schema_version == 1, "unsupported schemaVersion");
        anyhow::ensure!(
            (1..=1_000_000).contains(&self.rate_limit.max_requests),
            "rateLimit.maxRequests must be between 1 and 1000000"
        );
        anyhow::ensure!(
            (1..=3_600).contains(&self.rate_limit.window_seconds),
            "rateLimit.windowSeconds must be between 1 and 3600"
        );
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct RateLimitRuntimeConfig {
    pub max_requests: u64,
    pub window_seconds: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct WorkerRuntimeConfig {
    pub schema_version: u32,
    pub dispatcher_interval_millis: u64,
    pub scheduler_interval_millis: u64,
    pub reaper_interval_seconds: u64,
    pub cleanup_interval_seconds: u64,
}

impl WorkerRuntimeConfig {
    pub fn new(
        dispatcher_interval: Duration,
        scheduler_interval: Duration,
        reaper_interval: Duration,
        cleanup_interval: Duration,
    ) -> Self {
        Self {
            schema_version: 1,
            dispatcher_interval_millis: duration_millis(dispatcher_interval),
            scheduler_interval_millis: duration_millis(scheduler_interval),
            reaper_interval_seconds: reaper_interval.as_secs(),
            cleanup_interval_seconds: cleanup_interval.as_secs(),
        }
    }

    pub fn validate(&self) -> anyhow::Result<()> {
        anyhow::ensure!(self.schema_version == 1, "unsupported schemaVersion");
        anyhow::ensure!(
            (10..=60_000).contains(&self.dispatcher_interval_millis),
            "dispatcherIntervalMillis must be between 10 and 60000"
        );
        anyhow::ensure!(
            (100..=60_000).contains(&self.scheduler_interval_millis),
            "schedulerIntervalMillis must be between 100 and 60000"
        );
        anyhow::ensure!(
            (1..=3_600).contains(&self.reaper_interval_seconds),
            "reaperIntervalSeconds must be between 1 and 3600"
        );
        anyhow::ensure!(
            (1..=3_600).contains(&self.cleanup_interval_seconds),
            "cleanupIntervalSeconds must be between 1 and 3600"
        );
        Ok(())
    }

    pub fn dispatcher_interval(&self) -> Duration {
        Duration::from_millis(self.dispatcher_interval_millis)
    }

    pub fn scheduler_interval(&self) -> Duration {
        Duration::from_millis(self.scheduler_interval_millis)
    }

    pub fn reaper_interval(&self) -> Duration {
        Duration::from_secs(self.reaper_interval_seconds)
    }

    pub fn cleanup_interval(&self) -> Duration {
        Duration::from_secs(self.cleanup_interval_seconds)
    }
}

fn duration_millis(value: Duration) -> u64 {
    u64::try_from(value.as_millis()).unwrap_or(u64::MAX)
}

fn non_empty_env(name: &str) -> Option<String> {
    env::var(name)
        .ok()
        .map(|value| value.trim().to_owned())
        .filter(|value| !value.is_empty())
}

fn env_bool(name: &str, default: bool) -> anyhow::Result<bool> {
    match env::var(name) {
        Ok(value) if value.eq_ignore_ascii_case("true") || value == "1" => Ok(true),
        Ok(value) if value.eq_ignore_ascii_case("false") || value == "0" => Ok(false),
        Ok(_) => anyhow::bail!("{name} must be true/false or 1/0"),
        Err(env::VarError::NotPresent) => Ok(default),
        Err(error) => Err(error.into()),
    }
}

fn env_number(name: &str, default: u64, min: u64, max: u64) -> anyhow::Result<u64> {
    let value = match env::var(name) {
        Ok(value) => value
            .parse::<u64>()
            .with_context(|| format!("{name} must be an integer"))?,
        Err(env::VarError::NotPresent) => default,
        Err(error) => return Err(error.into()),
    };
    anyhow::ensure!(
        (min..=max).contains(&value),
        "{name} must be between {min} and {max}"
    );
    Ok(value)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn gateway_document_is_strict_and_validated() {
        let valid = r#"{
            "schemaVersion": 1,
            "rateLimit": {"maxRequests": 500, "windowSeconds": 30}
        }"#;
        let parsed: GatewayRuntimeConfig = serde_json::from_str(valid).unwrap();
        parsed.validate().unwrap();
        assert_eq!(parsed, GatewayRuntimeConfig::new(500, 30));

        let unknown = r#"{
            "schemaVersion": 1,
            "rateLimit": {"maxRequests": 500, "windowSeconds": 30},
            "jwtSecret": "must-never-be-dynamic"
        }"#;
        assert!(serde_json::from_str::<GatewayRuntimeConfig>(unknown).is_err());
    }

    #[test]
    fn worker_document_rejects_unsafe_intervals() {
        let config = WorkerRuntimeConfig {
            schema_version: 1,
            dispatcher_interval_millis: 1,
            scheduler_interval_millis: 1_000,
            reaper_interval_seconds: 5,
            cleanup_interval_seconds: 5,
        };
        assert!(config.validate().is_err());
    }

    #[test]
    fn listener_rejects_invalid_update_and_keeps_last_good_value() {
        let initial = GatewayRuntimeConfig::new(300, 60);
        let (sender, receiver) = watch::channel(initial.clone());
        let listener = JsonConfigListener {
            sender,
            validator: Arc::new(GatewayRuntimeConfig::validate),
        };
        listener.notify(ConfigResponse::new(
            "gateway.json".into(),
            DEFAULT_GROUP.into(),
            "rust-toon".into(),
            r#"{"schemaVersion":1,"rateLimit":{"maxRequests":0,"windowSeconds":60}}"#.into(),
            "json".into(),
            "invalid-md5".into(),
        ));
        assert_eq!(*receiver.borrow(), initial);
    }

    #[tokio::test]
    #[ignore = "requires a live r-nacos test container"]
    async fn live_rnacos_push_updates_the_receiver() {
        let server_addr =
            env::var("TEST_NACOS_SERVER_ADDR").unwrap_or_else(|_| "127.0.0.1:18848".into());
        let username = env::var("TEST_NACOS_USERNAME").unwrap_or_else(|_| "rust_toon".into());
        let password =
            env::var("TEST_NACOS_PASSWORD").unwrap_or_else(|_| "rust_toon_nacos_password".into());
        let data_id = format!(
            "rust-toon-live-test-{}-{}.json",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        );
        let config =
            NacosConfig {
                enabled: true,
                required: true,
                server_addr,
                namespace: String::new(),
                group: DEFAULT_GROUP.into(),
                data_id: data_id.clone(),
                app_name: "rust-toon-live-test".into(),
                username: Some(username),
                password: Some(password),
                cache_dir: PathBuf::from(env::var("TEST_NACOS_CACHE_DIR").unwrap_or_else(|_| {
                    format!("/tmp/rust-toon-nacos-test-{}", std::process::id())
                })),
                connect_timeout: Duration::from_secs(10),
            };
        let mut receiver;
        let dynamic = subscribe_json(
            config,
            GatewayRuntimeConfig::new(300, 60),
            GatewayRuntimeConfig::validate,
        )
        .await
        .unwrap();
        receiver = dynamic.receiver();
        let service = dynamic._service.as_ref().unwrap();
        let published = service
            .publish_config(
                data_id.clone(),
                DEFAULT_GROUP.into(),
                serde_json::to_string(&GatewayRuntimeConfig::new(777, 30)).unwrap(),
                Some("json".into()),
            )
            .await
            .unwrap();
        assert!(published);

        timeout(Duration::from_secs(15), receiver.changed())
            .await
            .expect("listener update timed out")
            .expect("listener channel closed");
        assert_eq!(receiver.borrow().rate_limit.max_requests, 777);

        let published = service
            .publish_config(
                data_id.clone(),
                DEFAULT_GROUP.into(),
                serde_json::to_string(&GatewayRuntimeConfig::new(888, 45)).unwrap(),
                Some("json".into()),
            )
            .await
            .unwrap();
        assert!(published);
        timeout(Duration::from_secs(10), receiver.changed())
            .await
            .expect("long-connection update timed out")
            .expect("listener channel closed");
        assert_eq!(receiver.borrow().rate_limit.max_requests, 888);

        service
            .remove_config(data_id, DEFAULT_GROUP.into())
            .await
            .unwrap();
    }
}
