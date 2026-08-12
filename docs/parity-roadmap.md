# 等价迁移清单

本项目不重新设计 Yudao 或 Toonflow 的业务。Rust 服务端以参照工程的接口、字段、状态流转和权限行为为验收标准。

## 基础后台（参照 `../yudao-cloud`）

- System：认证、用户、部门、岗位、角色、菜单、租户、字典、通知、OAuth2、社交登录
- Infra：配置、文件与文件配置、定时任务、API 日志、错误日志、数据源、代码生成
- BPM：模型、流程定义、流程实例、任务、抄送、表单、流程分类
- AI：模型、聊天、知识库、绘画、音乐、工作流及对应管理能力
- 横切能力：统一响应、校验、权限、租户隔离、审计、缓存、幂等、限流、导入导出

## 动漫工厂（参照 `../Toonflow-app`）

Toonflow-app 仅作为功能、流程、字段与交互语义的参照。前端不复制其原 UI 技术实现，全部使用本项目的 Vben Admin 5、Vue 3 和 Ant Design Vue 重建，并接入统一菜单、权限、标签页与布局体系；后端全部使用 Rust 实现。

- 项目：项目、导演手册、视觉手册、模型选择
- 小说与剧本：章节、事件、剧本、资产提取、Script Agent 计划
- 资产：角色/场景/道具、图片、音频、批量生成、提示词润色
- 生产：工作流、衍生资产、图片编辑、分镜、轨道、视频、配音
- Agent：Script Agent、Production Agent、记忆、工具调用和执行状态
- 设置：供应商、模型映射、提示词、Skill、Agent 部署、记忆、开发配置
- 任务中心：筛选、分页、分类、详情、轮询及失败原因
- API 层：Vben 调用 Rust 原生 `/toonflow/**` 接口；不保留会返回空对象或伪成功的通配兼容层

### 下一轮最高优先级

图片与视频生成稳定性作为下一轮 P0 工作，先修复参考图确定性映射、结构化镜头描述、模型专用 payload、生成前校验和生成后视觉质检，再继续调整自然语言提示词。详细实施顺序和验收标准见 [图片与视频生成稳定性优化计划](./media-generation-stability-plan.md)。

## 完成标准

每个条目必须同时具备 Rust 接口、数据库迁移、权限、前端入口或原页面调用兼容，并通过后端检查、前端类型检查和关键流程测试，才可标记完成。

当前仓库的准确实现范围以实际 Rust 路由、数据库迁移和 Vben 菜单为准。未实现能力必须返回明确的 404 或业务错误，不能通过空数组、空对象或固定 `true` 冒充成功。

## Toonflow 兼容端点状态

- 已覆盖：`novel/getNovelIndex`、`novel/batchDeleteNovel`、`production/assets/updateAssetsUrl`、`production/assets/deleteAssetsDireve`、`script/getAiRegex`、`script/exportScript`、`artStyle/extractStylePrompt`、`assets/addAudioAssets`、`assets/updateAudioAssets`、`assets/delAssets`、`modelSelect/getModelList`、`modelSelect/getModelDetail`、`other/getVersion`。
- 服务端专属能力：Agent WebSocket 支持 `updateContext`、心跳和断线超时；启动时会将被服务重启中断的生成任务标记为失败。
- 桌面端专属端点不移植：`checkUpdate`、`openFolder`、`selectFolder`、`openExternal` 等 Electron/本机文件管理能力。
