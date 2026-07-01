# Easylife 公开 Web Demo 交付说明

本文用于把 Easylife 准备成可公开访问的作品集 Web Demo。目标是让面试官无需手机号、
无需后端账号、无需本地环境，即可稳定进入主流程并理解项目工程价值。

## 1. Demo 定位

公开 Demo 展示的是 Flutter MVP 和本地优先架构，不是生产上线版本。

面试官打开 Demo 后会看到“进入作品演示”按钮。点击后进入 `portfolio-demo-user`，
首次进入会写入一组预置数据：

- 1 份用户画像
- 1 个陪伴伙伴档案
- 2 条情绪日记
- 3 条长期记忆
- 3 条饮食记录
- 3 条体重记录

这些数据只保存在当前浏览器本地存储中。Demo 不连接真实短信、真实后端、真实数据库或
真实 AI provider。

## 2. 发布前检查

在项目根目录运行：

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web --release
flutter build web --release --dart-define=EASYLIFE_DEMO_MODE=true
```

人工检查：

- 打开 Demo 页面后显示“进入作品演示”，不要求输入手机号。
- 点击“进入作品演示”后进入首页。
- 首页能看到伙伴、每日运势和今日状态。
- 陪伴页可以发送文本并保存情绪日记。
- 长期记忆页面可以查看预置记忆。
- 饮食页可以查看预置记录和饮食回顾。
- 刷新页面后仍保留本地数据。
- 退出后重新进入 Demo，不覆盖用户已经编辑过的数据。

## 3. 构建命令

公开 Demo 构建：

```bash
flutter build web --release \
  --dart-define=EASYLIFE_DEMO_MODE=true
```

如果托管在域名根路径，直接发布 `build/web` 即可。

如果托管在 GitHub Pages 子路径，追加对应 `--base-href`：

```bash
flutter build web --release \
  --dart-define=EASYLIFE_DEMO_MODE=true \
  --base-href=/your-repo-name/
```

## 4. 免费静态托管

### Netlify Drop

1. 运行公开 Demo 构建命令。
2. 打开 Netlify Drop。
3. 将 `build/web` 文件夹拖入页面。
4. 等待生成公开 URL。
5. 打开 URL，完成发布前人工检查。

`web/_redirects` 会被复制到 `build/web/_redirects`，用于把刷新或直接访问路径回退到
`index.html`。

### Cloudflare Pages

推荐配置：

```text
Build command:
flutter build web --release --dart-define=EASYLIFE_DEMO_MODE=true

Build output directory:
build/web
```

如果 Cloudflare Pages 的构建环境没有 Flutter，可先本地构建，再上传 `build/web`
作为静态产物。

### Vercel Static

推荐配置：

```text
Build command:
flutter build web --release --dart-define=EASYLIFE_DEMO_MODE=true

Output directory:
build/web
```

如果 Vercel 构建环境没有 Flutter，同样建议本地构建后上传静态产物。

## 5. 演示视频脚本

建议视频长度：90-120 秒。

```text
0-8 秒
打开公开 Demo 链接。说明：这是 Easylife 的作品集 Web Demo，不需要手机号或后端账号。

8-18 秒
点击“进入作品演示”，进入首页。说明：Demo 会为面试官准备一组本地预置数据。

18-32 秒
展示首页的伙伴状态、每日运势和今日状态。说明：项目聚焦低压陪伴，而不是传统健康工具式数据堆叠。

32-52 秒
切到“陪伴”，输入“今天有点累，但把重要的事做完了”。发送后展示伙伴回复。
说明：单轮体验保持朋友式陪伴，不直接展示报告式分析。

52-68 秒
点击“保存情绪日记”，打开日记详情。
说明：只有用户确认保存后，才把对话沉淀成情绪日记和有限长期记忆。

68-82 秒
进入“我的 -> 长期记忆”。展示记忆列表。
说明：长期记忆可由用户查看、添加、修改和删除，不保存完整逐字聊天历史。

82-102 秒
进入“饮食”，展示今日饮食记录和饮食回顾。可快速演示一句话记录到贴纸保存。
说明：饮食模块重点是记录、复盘和可执行建议。

102-115 秒
刷新页面或退出再进 Demo。说明：本地优先数据会保留，且不会覆盖用户编辑。

115-120 秒
收尾：说明项目包含 Flutter 客户端、Service / Repository 分层、本地持久化、OpenAPI 契约和后端认证骨架。
```

## 6. 作品集介绍文案

### 短版

Easylife 是一个 Flutter 实现的 AI 生活陪伴 App MVP。项目围绕用户画像、陪伴对话、
情绪日记、长期记忆、饮食体重和每日运势构建闭环，并提供可公开访问的 Web Demo。
工程上采用本地优先、Service / Repository 分层和 OpenAPI 契约先行，AI 与认证能力
通过 Mock 和 HTTP 边界隔离，便于后续替换真实后端。

### 长版

Easylife 是一个面向 iOS 首发和 Web 作品集演示的 AI 生活陪伴 App MVP。它把用户画像、
桌宠陪伴、情绪记录、长期记忆、饮食体重和每日运势连接成一个低压、温和的日常陪伴闭环。

我负责从产品范围收敛到 Flutter 客户端实现、数据分层、本地持久化、AI 边界设计、
OpenAPI 契约和 Node.js / PostgreSQL 后端认证骨架的整体搭建。客户端页面只处理展示和
流程编排，AI、认证和数据读写分别下沉到 service、repository 和 HTTP 边界。公开 Demo
使用本地预置数据和 Mock AI，让面试官无需账号即可稳定体验完整主流程。

项目重点不是把 Mock 包装成生产能力，而是展示真实 App 工程中如何定义边界：什么可以
本地优先，什么需要服务端保护，什么属于可替换的 AI provider，以及用户长期记忆如何
做到确认后沉淀、可查看、可编辑、可删除。

### 简历版

Easylife：基于 Flutter 的 AI 生活陪伴 App MVP。负责产品范围收敛、Flutter 多端 UI、
Service / Repository 分层、本地优先持久化、长期记忆机制、OpenAPI 契约和 Node.js
认证后端骨架；实现用户画像、陪伴对话、情绪日记、长期记忆、饮食体重记录和公开 Web
Demo，并通过 Widget / service 测试覆盖核心流程。

## 7. 面试讲解要点

- 为什么做本地优先：先保证 Demo 和弱网体验稳定，再逐步接入同步。
- 为什么保留 Mock：Mock 是稳定演示和测试夹具，不伪装成真实 AI。
- 为什么 Flutter 不放 API Key：模型密钥和供应商 SDK 必须留在后端。
- 为什么长期记忆需要四层：当轮对话、确认沉淀、可管理记忆、个性化调用。
- 为什么 OpenAPI 先行：前后端并行开发时字段、错误码和保存时机需要统一事实来源。
