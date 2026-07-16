use serde::Serialize;

#[derive(Debug, Serialize)]
pub struct InfraCapability {
    pub module: &'static str,
    pub capabilities: [&'static str; 4],
}

impl Default for InfraCapability {
    fn default() -> Self {
        Self {
            module: "infra",
            capabilities: ["config", "file", "job", "monitor"],
        }
    }
}
