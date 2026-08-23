# 功能范围与验收口径

本文档记录当前 Rust Toon 的实现边界。验收以仓库中的 Rust 路由、数据库迁移和 Toonflow 前端为准；外部项目只用于参考交互语义，不代表必须复制所有功能。

## 已实现模块

- System：认证、用户、角色、权限、菜单、字典、租户和审计日志。
- Infra：配置、文件、定时任务、代码生成、访问日志和监控。
- AI：模型配置、对话、知识库、图片/视频/音乐/语音等媒体能力。
- Media：媒体资产管理。
- Toonflow：项目、小说、剧本、事件、资产、分镜、音视频、Agent、提示词、技能和任务中心。

## 当前边界

- BPM/Yudao 工作流管理不在当前实现范围内；旧的 BPM 前端、API、菜单和字典数据已经移除。
- NATS、租户和部分高级 Provider 保留为扩展点，是否启用取决于部署配置和模型配置。
- 真实图片、视频和语音供应商需要有效凭据，默认测试不会调用付费服务。

## 验收方式

```bash
cargo test --workspace
bash script/test-database-migrations.sh
bash script/test-ai-e2e.sh
pnpm --dir apps/web --filter @vben/web-antd run typecheck
pnpm --dir apps/web --filter @vben/web-antd run build
```

生产部署和环境变量请参阅 [deployment.md](deployment.md) 与 [configuration.md](configuration.md)。
