use std::{env, fmt, time::Duration};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LogFormat {
    Text,
    Json,
}

impl fmt::Display for LogFormat {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(match self {
            Self::Text => "text",
            Self::Json => "json",
        })
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TelemetryConfig {
    pub service_name: String,
    pub log_format: LogFormat,
    pub metrics_enabled: bool,
    pub otlp_endpoint: Option<String>,
    pub otlp_timeout: Duration,
}

impl TelemetryConfig {
    pub fn from_env(service_name: impl Into<String>) -> anyhow::Result<Self> {
        Self::from_lookup(service_name.into(), |key| env::var(key).ok())
    }

    fn from_lookup(
        service_name: String,
        lookup: impl Fn(&str) -> Option<String>,
    ) -> anyhow::Result<Self> {
        let log_format = match lookup("TELEMETRY_LOG_FORMAT")
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .unwrap_or("text")
            .to_ascii_lowercase()
            .as_str()
        {
            "text" | "plain" => LogFormat::Text,
            "json" => LogFormat::Json,
            value => anyhow::bail!("TELEMETRY_LOG_FORMAT must be text or json, received {value:?}"),
        };
        let metrics_enabled = parse_bool(
            "TELEMETRY_METRICS_ENABLED",
            lookup("TELEMETRY_METRICS_ENABLED"),
            true,
        )?;
        let sdk_disabled = parse_bool("OTEL_SDK_DISABLED", lookup("OTEL_SDK_DISABLED"), false)?;
        let otlp_endpoint = if sdk_disabled {
            None
        } else {
            lookup("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT")
                .or_else(|| lookup("OTEL_EXPORTER_OTLP_ENDPOINT"))
                .map(|value| value.trim().trim_end_matches('/').to_string())
                .filter(|value| !value.is_empty())
        };
        let timeout_ms = if sdk_disabled {
            10_000
        } else if let Some(value) = lookup("OTEL_EXPORTER_OTLP_TRACES_TIMEOUT") {
            parse_number(
                "OTEL_EXPORTER_OTLP_TRACES_TIMEOUT",
                Some(value),
                10_000,
                100,
                300_000,
            )?
        } else {
            parse_number(
                "OTEL_EXPORTER_OTLP_TIMEOUT",
                lookup("OTEL_EXPORTER_OTLP_TIMEOUT"),
                10_000,
                100,
                300_000,
            )?
        };

        Ok(Self {
            service_name,
            log_format,
            metrics_enabled,
            otlp_endpoint,
            otlp_timeout: Duration::from_millis(timeout_ms),
        })
    }
}

fn parse_bool(name: &str, value: Option<String>, default: bool) -> anyhow::Result<bool> {
    let Some(value) = value else {
        return Ok(default);
    };
    match value.trim().to_ascii_lowercase().as_str() {
        "1" | "true" | "yes" | "on" => Ok(true),
        "0" | "false" | "no" | "off" => Ok(false),
        _ => anyhow::bail!("{name} must be a boolean"),
    }
}

fn parse_number(
    name: &str,
    value: Option<String>,
    default: u64,
    minimum: u64,
    maximum: u64,
) -> anyhow::Result<u64> {
    let value = value
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::parse::<u64>)
        .transpose()
        .map_err(|_| anyhow::anyhow!("{name} must be an integer"))?
        .unwrap_or(default);
    anyhow::ensure!(
        (minimum..=maximum).contains(&value),
        "{name} must be between {minimum} and {maximum}"
    );
    Ok(value)
}

#[cfg(test)]
mod tests {
    use std::collections::HashMap;

    use super::{LogFormat, TelemetryConfig};

    fn config(values: &[(&str, &str)]) -> anyhow::Result<TelemetryConfig> {
        let values = values
            .iter()
            .map(|(key, value)| ((*key).to_string(), (*value).to_string()))
            .collect::<HashMap<_, _>>();
        TelemetryConfig::from_lookup("test-service".to_string(), |key| values.get(key).cloned())
    }

    #[test]
    fn defaults_do_not_create_an_external_exporter() {
        let config = config(&[]).unwrap();
        assert_eq!(config.log_format, LogFormat::Text);
        assert!(config.metrics_enabled);
        assert!(config.otlp_endpoint.is_none());
    }

    #[test]
    fn explicit_otlp_and_json_configuration_is_parsed() {
        let config = config(&[
            ("TELEMETRY_LOG_FORMAT", "json"),
            ("TELEMETRY_METRICS_ENABLED", "false"),
            ("OTEL_EXPORTER_OTLP_ENDPOINT", "http://collector:4317/"),
            ("OTEL_EXPORTER_OTLP_TIMEOUT", "2500"),
        ])
        .unwrap();
        assert_eq!(config.log_format, LogFormat::Json);
        assert!(!config.metrics_enabled);
        assert_eq!(
            config.otlp_endpoint.as_deref(),
            Some("http://collector:4317")
        );
        assert_eq!(config.otlp_timeout.as_millis(), 2500);
    }

    #[test]
    fn sdk_disabled_wins_over_an_endpoint() {
        let config = config(&[
            ("OTEL_SDK_DISABLED", "true"),
            ("OTEL_EXPORTER_OTLP_ENDPOINT", "http://collector:4317"),
            ("OTEL_EXPORTER_OTLP_TIMEOUT", "invalid-but-disabled"),
        ])
        .unwrap();
        assert!(config.otlp_endpoint.is_none());
    }

    #[test]
    fn rejects_ambiguous_values() {
        assert!(config(&[("TELEMETRY_LOG_FORMAT", "yaml")]).is_err());
        assert!(config(&[("TELEMETRY_METRICS_ENABLED", "maybe")]).is_err());
        assert!(config(&[("OTEL_EXPORTER_OTLP_TIMEOUT", "99")]).is_err());
    }

    #[test]
    fn trace_specific_timeout_takes_precedence() {
        let config = config(&[
            ("OTEL_EXPORTER_OTLP_TIMEOUT", "5000"),
            ("OTEL_EXPORTER_OTLP_TRACES_TIMEOUT", "1500"),
        ])
        .unwrap();
        assert_eq!(config.otlp_timeout.as_millis(), 1500);
    }
}
