use axum::Json;
use serde_json::{Value, json};

pub async fn document() -> Json<Value> {
    Json(json!({
        "openapi": "3.1.0",
        "info": {
            "title": "Rust Toon Gateway API",
            "version": "0.1.0"
        },
        "servers": [{ "url": "/api" }],
        "components": {
            "securitySchemes": {
                "bearerAuth": {
                    "type": "http",
                    "scheme": "bearer",
                    "bearerFormat": "JWT"
                }
            }
        },
        "paths": {
            "/system/capabilities": { "get": { "tags": ["system"], "summary": "System module capabilities", "responses": { "200": { "description": "OK" } } } },
            "/system/auth/login": { "post": { "tags": ["auth"], "summary": "Login", "responses": { "200": { "description": "Token pair" }, "401": { "description": "Invalid credentials" } } } },
            "/system/auth/refresh-token": { "get": { "tags": ["auth"], "summary": "Refresh access token", "responses": { "200": { "description": "Rotated token pair" }, "401": { "description": "Invalid refresh token" } } } },
            "/system/auth/logout": { "post": { "tags": ["auth"], "summary": "Logout and revoke refresh token", "responses": { "200": { "description": "OK" } } } },
            "/system/auth/me": { "get": { "tags": ["auth"], "summary": "Current user", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Current user permissions" } } } },
            "/system/users": {
                "get": { "tags": ["system-user"], "summary": "List users", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Users" } } },
                "post": { "tags": ["system-user"], "summary": "Create user", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Created user id" } } }
            },
            "/system/users/{id}": {
                "put": { "tags": ["system-user"], "summary": "Update user", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "OK" } } },
                "delete": { "tags": ["system-user"], "summary": "Delete user", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "OK" } } }
            },
            "/system/users/{id}/roles": { "put": { "tags": ["system-user"], "summary": "Assign user roles", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "OK" } } } },
            "/system/roles": {
                "get": { "tags": ["system-role"], "summary": "List roles", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Roles" } } },
                "post": { "tags": ["system-role"], "summary": "Create role", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Created role id" } } }
            },
            "/system/roles/{id}": {
                "put": { "tags": ["system-role"], "summary": "Update role", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "OK" } } },
                "delete": { "tags": ["system-role"], "summary": "Delete role", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "OK" } } }
            },
            "/system/roles/{id}/permissions": { "put": { "tags": ["system-role"], "summary": "Assign role permissions", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "OK" } } } },
            "/system/permissions": { "get": { "tags": ["system-permission"], "summary": "List permissions", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Permissions" } } } },
            "/system/audit-logs": { "get": { "tags": ["system-audit"], "summary": "List audit logs", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Audit logs" } } } },
            "/livez": { "get": { "tags": ["ops"], "summary": "Process liveness", "responses": { "200": { "description": "Process is alive" } } } },
            "/readyz": { "get": { "tags": ["ops"], "summary": "Dependency readiness", "responses": { "200": { "description": "Required dependencies are ready" }, "503": { "description": "A required dependency is unavailable" } } } },
            "/metrics": { "get": { "tags": ["ops"], "summary": "Prometheus/OpenMetrics scrape endpoint", "responses": { "200": { "description": "OpenMetrics text exposition" } } } },
            "/health": { "get": { "tags": ["ops"], "summary": "Backward-compatible process health", "responses": { "200": { "description": "Process is alive" } } } },
            "/infra/capabilities": { "get": { "tags": ["infra"], "summary": "Infra module capabilities", "responses": { "200": { "description": "OK" } } } },
            "/toon/capabilities": { "get": { "tags": ["toon"], "summary": "Toon module capabilities", "responses": { "200": { "description": "OK" } } } },
            "/toon/projects": {
                "get": { "tags": ["toon"], "summary": "List toon projects", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Projects" } } },
                "post": { "tags": ["toon"], "summary": "Create toon project", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Created project id" } } }
            },
            "/toon/projects/{id}": {
                "get": { "tags": ["toon"], "summary": "Get toon project", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Project" } } },
                "put": { "tags": ["toon"], "summary": "Update toon project", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "OK" } } },
                "delete": { "tags": ["toon"], "summary": "Delete toon project", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "OK" } } }
            },
            "/toon/projects/{id}/publish": { "post": { "tags": ["toon"], "summary": "Publish toon project", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Publication id" } } } },
            "/toon/projects/{project_id}/episodes": {
                "get": { "tags": ["toon"], "summary": "List episodes", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Episodes" } } },
                "post": { "tags": ["toon"], "summary": "Create episode", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Created episode id" } } }
            },
            "/toon/episodes/{id}": {
                "put": { "tags": ["toon"], "summary": "Update episode", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "OK" } } },
                "delete": { "tags": ["toon"], "summary": "Delete episode", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "OK" } } }
            },
            "/toon/episodes/{episode_id}/scenes": {
                "get": { "tags": ["toon"], "summary": "List scenes", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Scenes" } } },
                "post": { "tags": ["toon"], "summary": "Create scene", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Created scene id" } } }
            },
            "/toon/scenes/{id}": {
                "put": { "tags": ["toon"], "summary": "Update scene", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "OK" } } },
                "delete": { "tags": ["toon"], "summary": "Delete scene", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "OK" } } }
            },
            "/toonflow/projects/{project_id}/video-archive": {
                "get": { "tags": ["toonflow-video-archive"], "summary": "List final video renders grouped by episode", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Project video archive" }, "404": { "description": "Project not found or inaccessible" } } }
            },
            "/toonflow/projects/{project_id}/episodes/{script_id}/renders": {
                "get": { "tags": ["toonflow-video-archive"], "summary": "List final render versions for one episode", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Episode render versions" }, "404": { "description": "Project or episode not found" } } }
            },
            "/toonflow/episode-renders/{render_id}/current": {
                "patch": { "tags": ["toonflow-video-archive"], "summary": "Select the current final render version", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Selected episode render" }, "400": { "description": "Render is not ready" }, "404": { "description": "Render not found or inaccessible" } } }
            },
            "/media/capabilities": { "get": { "tags": ["media"], "summary": "Media module capabilities", "responses": { "200": { "description": "OK" } } } },
            "/media/assets": {
                "get": { "tags": ["media"], "summary": "List media assets", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Assets" } } },
                "post": { "tags": ["media"], "summary": "Create media asset", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Created asset id" } } }
            },
            "/media/assets/{id}": {
                "get": { "tags": ["media"], "summary": "Get media asset", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "Asset" } } },
                "put": { "tags": ["media"], "summary": "Update media asset", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "OK" } } },
                "delete": { "tags": ["media"], "summary": "Delete media asset", "security": [{ "bearerAuth": [] }], "responses": { "200": { "description": "OK" } } }
            }
        }
    }))
}
