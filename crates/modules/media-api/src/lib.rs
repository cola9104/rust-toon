use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Debug, Serialize)]
pub struct MediaCapability {
    pub module: &'static str,
    pub capabilities: [&'static str; 4],
}

#[derive(Debug, Serialize)]
pub struct AssetSummary {
    pub id: String,
    pub object_key: String,
    pub filename: Option<String>,
    pub content_type: String,
    pub size_bytes: i64,
    pub status: String,
    pub checksum: Option<String>,
    pub metadata: Value,
    pub owner_user_id: Option<String>,
    pub created_at: String,
}

#[derive(Debug, Deserialize)]
pub struct CreateAssetRequest {
    pub object_key: String,
    pub filename: Option<String>,
    pub content_type: String,
    pub size_bytes: i64,
    pub checksum: Option<String>,
    #[serde(default)]
    pub metadata: Value,
}

#[derive(Debug, Deserialize)]
pub struct UpdateAssetRequest {
    pub filename: Option<String>,
    pub status: String,
    pub checksum: Option<String>,
    #[serde(default)]
    pub metadata: Value,
}

impl Default for MediaCapability {
    fn default() -> Self {
        Self {
            module: "media",
            capabilities: ["asset-library", "upload", "transcoding", "storage-binding"],
        }
    }
}
