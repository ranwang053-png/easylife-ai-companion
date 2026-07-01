# Easylife - AI 生活陪伴 App 作品集项目

Easylife 是一个 Flutter 实现的 AI 生活陪伴 App MVP，面向 iOS 首发与 Web
作品集演示。项目把用户画像、桌宠陪伴、情绪记录、长期记忆、饮食与体重记录串成一个
本地优先的闭环，并保留每日运势作为首页固定卡片。

这个仓库不是一个只展示页面的原型，而是围绕真实 App 工程边界搭建的作品集项目：
Flutter 客户端、Service / Repository 分层、本地持久化、HTTP 接入边界、OpenAPI
契约、Node.js 后端认证骨架、PostgreSQL 迁移和测试套件都已经在同一项目中组织好。

## 我负责的内容

- 产品范围收敛：确定 MVP 聚焦用户画像、陪伴对话、情绪日记、长期记忆、饮食体重和每日运势。
- Flutter 客户端：登录注册、用户画像、主导航、首页、陪伴、饮食、我的、设置等核心流程。
- 工程分层：页面只处理展示和流程编排，AI、认证和数据读写下沉到 service / repository。
- 本地优先：使用 `shared_preferences` 和安全存储完成用户、伙伴、情绪、饮食、体重和会话恢复。
- AI 边界：实现稳定的 `MockAgentService`，并预留 `HttpAgentService` 接入自建后端。
- 后端雏形：基于 OpenAPI 的 Node.js / Express 服务、真实认证路径、数据库迁移和 worker 入口。
- 质量保障：覆盖核心 Widget 流程、三档响应式布局、认证状态机、持久化、Demo 播种和 HTTP 回退测试。
- 作品集演示：提供 `EASYLIFE_DEMO_MODE`，可无短信进入带完整预置数据的 Web Demo。

## 核心功能闭环

```text
登录 / 作品集 Demo 入口
    -> 用户基础信息
    -> 主 App
        -> 首页：伙伴状态、每日运势、今日记录状态
        -> 陪伴：多轮文字 / 语音转写输入、陪伴回复、情绪日记保存
        -> 饮食：食物描述、热量估算、贴纸保存、体重记录、饮食回顾
        -> 我的：用户画像、伙伴档案、长期记忆、系统偏好
```

陪伴模块的关键设计是“先陪伴，再沉淀”。用户发送内容后，页面保留朋友式对话气泡；
只有用户主动点击“保存情绪日记”后，才生成结构化情绪日记，并提炼有限条长期记忆。
饮食模块则以记录和复盘为主，不把页面做成流水账，而是提供日 / 周 / 月的结构化回顾。

## 长期记忆四层架构

```text
1. 当轮对话层
   用户与伙伴的本轮交流，只用于当前体验，不长期保存逐字聊天记录。

2. 确认沉淀层
   用户主动保存后，才把本轮表达整理成一条情绪日记。

3. 可管理记忆层
   从日记中提炼少量本地长期记忆，写入 UserProfile.memoryNotes。
   用户可以在长期记忆页面查看、添加、修改和删除。

4. 个性化调用层
   AgentService 后续分析时只接收经过筛选和限量的记忆上下文。
   当前本地最多保留最近 12 条，避免保存完整聊天历史。
```

这个设计的重点是把“陪伴感”和“可控记忆”分开：AI 不自动永久记住所有话，用户确认后才沉淀；
已沉淀的长期记忆也能被用户直接管理。

## 数据流与工程分层

```text
Flutter Page
    -> Service
        -> Repository / LocalStore
        -> HTTP Client
            -> Node.js / Express API
                -> PostgreSQL / AI Provider
```

客户端的主要边界：

- `lib/pages/`：页面、导航和流程编排。
- `lib/services/agent_service.dart`：AI 能力统一入口，包含 Mock 与 HTTP 实现。
- `lib/services/auth_service.dart`：短信认证、Token 刷新和退出的客户端抽象。
- `lib/services/auth_session_service.dart`：会话恢复、刷新和安全存储。
- `lib/services/journal_repository.dart`：情绪、饮食、体重等日志型数据访问。
- `lib/services/local_store.dart`：本地键值存储抽象、内存测试替身和用户级前缀隔离。
- `contracts/openapi.yaml`：前后端契约的唯一事实来源。
- `backend/server/`：Express API、OpenAPI 校验、认证实现和 worker 入口。
- `backend/database/migrations/`：PostgreSQL 版本化迁移。

页面不直接持有 Prompt、模型供应商逻辑或 API Key；结构化业务能力通过 service 注入，
因此 Mock、本地测试、HTTP 后端和未来真实 AI provider 可以在边界内替换。

## 本地优先设计

当前客户端优先保证无后端也能完成作品集演示和核心流程：

- 业务数据按已认证用户 ID 增加本地存储前缀，避免同设备切换账号串数据。
- 用户画像、伙伴档案、情绪日记、饮食记录、体重记录和引导状态本地持久化。
- 会话 token 使用系统安全存储，启动时恢复，访问令牌临近过期时自动刷新。
- 本地 JSON 解析失败时回退到可用初始数据，避免坏数据直接阻断页面。
- Widget 测试使用内存 store，确保测试隔离且不依赖真实设备存储。
- 作品集 Demo 只在指定编译开关下播种数据，不覆盖用户后续编辑。

后续云端同步规划采用“本地先写、联网后增量同步”的方向，第一阶段同步用户画像、
伙伴档案、情绪日记和长期记忆；饮食和体重留作第二阶段扩展。

## Mock、真实 AI 与生产边界

已完成或已接入边界：

- `MockAgentService`：当前大部分 AI 体验的本地稳定实现，用于内测、演示和测试。
- `HttpAgentService`：已支持通过 `EASYLIFE_API_BASE_URL` 调用 `/v1/emotion/analyze`。
- 情绪分析失败回退：后端不可用、超时或返回异常时，客户端回退本地结果并标记为本地分析。
- Node.js 后端：已实现 OpenAPI 路由、认证路径、PostgreSQL 认证、迁移和 worker 入口。
- 固定响应与固定认证：仅用于开发、测试和作品集 Demo，不代表真实短信或真实 AI 已上线。

尚未声明为生产完成：

- 真实短信供应商账号和生产 HTTPS 网关联调。
- 持久化生产数据库部署、生产密钥和监控配置。
- 真实模型 provider 接入、成本监控和安全评估。
- 云端同步事务、对象存储、第三方数据删除和 TestFlight 全流程验收。

Flutter 客户端不会保存模型 API Key，也不会直接调用需要私密凭证的模型接口。

## 本地运行

安装依赖：

```bash
flutter pub get
```

本地运行：

```bash
flutter run
```

连接自建后端：

```bash
flutter run \
  --dart-define=EASYLIFE_API_BASE_URL=https://api.example.com
```

本地 Web 预览可使用固定示例认证；作品集 Demo 可直接进入预置数据：

```bash
flutter run -d chrome \
  --dart-define=EASYLIFE_DEMO_MODE=true
```

## 公开 Web Demo

公开 Demo 面向面试官和作品集读者，推荐使用 `EASYLIFE_DEMO_MODE=true` 构建。打开链接后
无需手机号和验证码，点击“进入作品演示”即可进入带预置数据的主流程。

推荐体验路径：

1. 首页查看伙伴状态、每日运势和今日记录状态。
2. 进入“陪伴”，发送一段情绪内容，查看伙伴回复。
3. 点击“保存情绪日记”，查看温和整理后的日记详情。
4. 进入“我的 -> 长期记忆”，查看可管理的长期记忆。
5. 进入“饮食”，用一句话记录食物，确认热量并保存贴纸。
6. 查看日 / 周 / 月饮食回顾。

Demo 边界：

- 数据只保存在当前浏览器本地存储中，不上传到云端。
- AI 回复、热量估算和伙伴形象仍使用本地 Mock 或占位实现。
- 公开 Demo 不连接真实短信、真实后端、真实数据库或真实 AI provider。
- 再次进入 Demo 不会覆盖面试官已经编辑过的数据；如需重置，可清除浏览器站点数据后重新打开。

构建公开 Demo：

```bash
flutter build web --release \
  --dart-define=EASYLIFE_DEMO_MODE=true
```

免费静态托管建议：

- Netlify Drop：将 `build/web` 文件夹拖到 Netlify Drop 页面即可得到公开链接。
- Cloudflare Pages：构建命令使用上面的 Demo 构建命令，输出目录填写 `build/web`。
- Vercel Static：构建命令使用上面的 Demo 构建命令，输出目录填写 `build/web`。

如果部署在 GitHub Pages 的子路径，需要额外传入匹配仓库路径的 `--base-href`，例如：

```bash
flutter build web --release \
  --dart-define=EASYLIFE_DEMO_MODE=true \
  --base-href=/your-repo-name/
```

更完整的部署检查、视频脚本和作品集介绍文案见
[`docs/WEB_DEMO_DELIVERY.md`](docs/WEB_DEMO_DELIVERY.md)。

## 测试与构建

常规检查：

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Web release 构建：

```bash
flutter build web --release
```

作品集 Demo Web 构建：

```bash
flutter build web --release \
  --dart-define=EASYLIFE_DEMO_MODE=true
```

后端验证：

```bash
cd backend/server
npm install
npm run typecheck
npm run build
npm test
```

## 本次测试结果

最后验证时间：2026-06-27。

| 命令 | 结果 |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib test` | 通过，57 个文件检查，0 个变更 |
| `flutter analyze` | 通过，No issues found |
| `flutter test` | 通过，65 个测试全部通过 |
| `flutter build web --release` | 通过，输出 `build/web` |
| `flutter build web --release --dart-define=EASYLIFE_DEMO_MODE=true` | 通过，输出可公开部署的 Demo 产物 |

当前 Flutter 测试覆盖重点：

- 新用户登录、基础信息、主 App 进入流程。
- 手机、平板、桌面三档主页面响应式布局。
- 首页每日运势、伙伴状态、主导航和核心入口。
- 陪伴对话、保存情绪日记、长期记忆增删改和隐私展示。
- 饮食记录、热量估算、重新计算、贴纸保存、防重复提交和异步退出。
- 体重记录、饮食回顾、系统偏好和设置页保存。
- 认证错误码、Token 刷新、退出、会话恢复和本地数据隔离。
- 作品集 Demo 数据播种、刷新、退出后重新进入的持久化行为。

## 截图 / GIF 占位清单

建议补充以下素材到作品集页面或简历附件：

- 首页：桌宠状态、每日运势卡片、今日记录状态。
- 陪伴：发送一条情绪输入、收到伙伴回复、点击保存情绪日记。
- 情绪日记详情：温和卡片式整理结果。
- 长期记忆：记忆列表、添加 / 修改 / 删除操作。
- 饮食：一句话记录、热量确认、贴纸保存到今日手帐。
- 饮食回顾：日 / 周 / 月复盘切换。
- 我的 / 设置：用户画像、伙伴档案、隐私偏好。
- 作品集 Demo：无短信进入预置用户数据。
- 响应式对比：390px、820px、1280px 三档布局。

## 后续可扩展方向

以下方向是工程上已预留边界或产品上合理的下一步，不代表已经完成：

- 接入真实 AI provider，并增加输出 schema 校验、成本监控和安全降级。
- 部署真实短信网关、持久化 PostgreSQL、生产密钥和后台 worker。
- 完成云端同步事务、离线 outbox、冲突解决和墓碑删除。
- 补齐 iOS 签名、CocoaPods、完整 Xcode 环境和 TestFlight 验收。
- 增加截图自动化、视觉回归和端到端验收脚本。
- 在不改变 MVP 主导航的前提下继续打磨 UI 动效、空状态和可访问性。
