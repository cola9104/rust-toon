use chrono::Utc;
use jsonwebtoken::{Algorithm, DecodingKey, EncodingKey, Header, Validation, decode, encode};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::{CurrentUser, SecurityConfig, SecurityError};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Claims {
    pub sub: String,
    pub iss: String,
    pub aud: String,
    pub iat: i64,
    pub exp: i64,
    pub jti: String,
    pub user: CurrentUser,
}

#[derive(Clone)]
pub struct TokenService {
    encoding_key: EncodingKey,
    decoding_key: DecodingKey,
    config: SecurityConfig,
}

impl TokenService {
    pub fn new(config: SecurityConfig) -> Self {
        Self {
            encoding_key: EncodingKey::from_secret(config.jwt_secret.as_bytes()),
            decoding_key: DecodingKey::from_secret(config.jwt_secret.as_bytes()),
            config,
        }
    }

    pub fn issue_access_token(&self, user: CurrentUser) -> Result<String, SecurityError> {
        let issued_at = Utc::now().timestamp();
        let claims = Claims {
            sub: user.user_id.clone(),
            iss: self.config.issuer.clone(),
            aud: self.config.audience.clone(),
            iat: issued_at,
            exp: issued_at + self.config.access_token_ttl.as_secs() as i64,
            jti: Uuid::new_v4().to_string(),
            user,
        };

        encode(&Header::new(Algorithm::HS256), &claims, &self.encoding_key)
            .map_err(|_| SecurityError::InvalidCredentials)
    }

    pub fn access_token_ttl_seconds(&self) -> u64 {
        self.config.access_token_ttl.as_secs()
    }

    pub fn verify_access_token(&self, token: &str) -> Result<Claims, SecurityError> {
        let mut validation = Validation::new(Algorithm::HS256);
        validation.set_issuer(&[&self.config.issuer]);
        validation.set_audience(&[&self.config.audience]);
        validation.set_required_spec_claims(&["exp", "iss", "aud", "sub"]);

        decode::<Claims>(token, &self.decoding_key, &validation)
            .map(|data| data.claims)
            .map_err(|_| SecurityError::InvalidCredentials)
    }
}

#[cfg(test)]
mod tests {
    use std::time::Duration;

    use crate::{CurrentUser, DataScope, Permission, PermissionSet, SecurityConfig};

    use super::TokenService;

    fn user() -> CurrentUser {
        CurrentUser {
            user_id: "user-1".into(),
            username: "admin".into(),
            tenant_id: Some("tenant-1".into()),
            role_codes: vec!["admin".into()],
            permissions: PermissionSet::new([Permission::new("system:*:read").unwrap()]),
            data_scope: DataScope::All,
        }
    }

    #[test]
    fn issues_and_verifies_an_access_token() {
        let config = SecurityConfig::new(
            "a-secret-with-at-least-thirty-two-bytes",
            "issuer",
            "audience",
            Duration::from_secs(60),
        )
        .unwrap();
        let service = TokenService::new(config);

        let token = service.issue_access_token(user()).unwrap();
        let claims = service.verify_access_token(&token).unwrap();

        assert_eq!(claims.sub, "user-1");
        assert_eq!(claims.user.username, "admin");
    }
}
