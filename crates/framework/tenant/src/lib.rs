//! Tenant framework extension point.
//!
//! This crate will own tenant context propagation, tenant isolation helpers, and
//! data-scope conventions.

use serde::Serialize;

#[derive(Debug, Clone, Serialize)]
pub struct TenantContext {
    pub tenant_id: String,
}
