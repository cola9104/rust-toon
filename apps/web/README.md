# Rust Toon Web

Rust Toon 的前端工作区是 pnpm monorepo，主应用位于 `apps/web-antd`，使用 Vue 3、Ant Design Vue 和 Vben Admin 基础组件。

## 本地开发

环境要求：Node.js `22.18+`、pnpm `11+`。Node 25+ 不再内置 Corepack，请先单独安装 Corepack 或 pnpm。

```bash
corepack enable
pnpm install
pnpm dev:antd
```

开发服务器默认地址：<http://127.0.0.1:5666>。前端通过 `/api` 代理访问 Rust 网关 `http://127.0.0.1:8080`。

## 功能范围

- 登录、用户、角色、权限、菜单和系统配置
- AI 模型、对话、知识库及媒体生成
- Toonflow 项目、剧本、资产、分镜、音频、视频和 Agent 工作台
- 深色/浅色主题、响应式布局和统一的请求错误处理

当前前端不包含 BPM/Yudao 工作流管理页面；Toonflow 的工作流运行能力由 `/toonflow/*` 与 `/api/*` 接口提供。

## 检查与构建

```bash
pnpm --dir apps/web --filter @vben/web-antd run typecheck
pnpm --dir apps/web --filter @vben/web-antd run build
```

生产构建输出到 `apps/web/apps/web-antd/dist`。部署时请将 `/api/` 反向代理到网关，并把 SPA 未命中的路径回退到 `index.html`。

## 环境变量

开发环境配置位于 `apps/web/apps/web-antd/.env.development`。常用变量：

- `VITE_PORT`：前端开发端口，默认 `5666`
- `VITE_GLOB_API_URL`：API 代理目标，默认本地 Rust 网关
- `VITE_BASE_URL`：前端部署子路径，通常为 `/`

后端、数据库和生产部署说明见仓库根目录 [README.md](../../README.md) 与 [docs/deployment.md](../../docs/deployment.md)。
