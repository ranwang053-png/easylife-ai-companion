# Easylife 项目记忆

本文件是本项目供 Codex 和其他开发 Agent 使用的长期记忆。开始任务前先阅读
本文件，再阅读与任务直接相关的代码。完成重要功能、架构调整或产品决策后，
同步更新本文件中已经失效的内容。

## 1. 产品定位

Easylife 是一个 Flutter 实现的 AI 生活陪伴 App MVP。产品希望通过温和、低压、
有陪伴感的交互，把用户画像、桌宠陪伴、情绪记录和饮食体重连接起来。

当前阶段快速完成上述四项核心能力，并在首页保留每日运势卡片；不加入灵感创作、
塔罗等独立扩展板块。架构应保持可迭代，但不要为尚未进入 MVP 的功能提前增加代码和维护成本。
不把 Mock 行为伪装成真实 AI、真实账号系统或持久化后端。

自 2026-06-13 起冻结当前前端功能范围，不再新增页面、导航入口、业务模块或视觉
功能。下一阶段进入本地存储建设，优先解决现有用户数据在 App 重启后的持久化问题。
首发平台确定为 iOS；打包、真机验收、签名和 TestFlight 准备均以 iOS 为优先，
Android 打包环境暂缓，不作为当前内测上线阻塞项。

## 2. 当前实现状态

- 技术栈：Flutter、Dart、Material 3。
- 包名：`company_app`。
- App 入口：`lib/main.dart`。
- 启动流程：登录或注册 -> 用户基础信息 -> 主 App；宠物档案由用户之后按需创建。
- 主导航：`lib/pages/app_shell.dart`，包含首页、陪伴、饮食、我的。
- 首页聚焦桌宠互动、每日运势和今日记录状态。
- 陪伴模块支持情绪输入、Mock 分析、建议与历史展示。
- 饮食模块支持体重记录、食物描述或图片占位、Mock 热量估算和手帐贴纸流程。
- 我的与设置模块承载用户画像、宠物档案及偏好编辑。
- 当前 AI 能力由 `MockAgentService` 提供。
- 生产入口使用 `shared_preferences` 保存用户、宠物、情绪、饮食、体重和引导状态；
  Widget 测试继续使用内存实现隔离数据。
- 情绪分析可通过 `EASYLIFE_API_BASE_URL` 接入自建 HTTP 后端，未配置或失败时回退
  `MockAgentService`；其他 AI 能力本阶段仍为 Mock。
- 真实登录鉴权、云数据库、生产后端和真实模型调用尚未实现。
- 首发平台为 iOS；当前 Mac 已安装 Flutter，但只有 Apple Command Line Tools，
  尚未安装完整 Xcode 和 CocoaPods。当前 macOS 14.6 不能运行满足 2026 年
  App Store Connect 上传要求的 Xcode 26，需先升级 macOS。
- 当前前端范围已冻结；只允许为持久化接入所必需的状态加载、错误提示和兼容性调整，
  不借机新增或重设计用户功能。
- 每日运势是首页固定卡片，包含整体运势、幸运色、幸运食物、幸运数字、幸运花、
  事业/财富/爱情/人际分数、建议和避免；灵感创作与塔罗不属于当前 MVP。

`README.md` 和 `DELIVERY.md` 可用于了解背景，但可能晚于代码更新。发生冲突时，
以当前代码、测试和 `pubspec.yaml` 为事实来源，并修正文档。

## 3. 架构边界

页面只负责展示、输入和流程编排，不直接包含 Prompt、模型供应商逻辑或 API Key。

```text
Flutter Page
    -> AgentService
        -> MockAgentService（当前）
        -> HttpAgentService（未来）
            -> 自建 Node.js / Express API
                -> AI Model + Database
```

必须遵守：

- 前端冻结期间，不新增页面、底部导航项、首页卡片、业务入口或独立功能模块。
- 非持久化所必需的 UI 重构、视觉改版和交互扩展暂缓。
- 本地存储和单一情绪分析 AI 接入优先于其他远程能力、图片上传和新功能开发。
- AI 业务统一通过 `lib/services/agent_service.dart` 的 `AgentService` 抽象。
- 新增 AI 能力时，先扩展结构化 model 和 service 接口，再接入页面。
- Flutter 客户端不得保存模型 API Key，也不得直接调用需要私密凭证的模型接口。
- 未来后端优先自建 Node.js / Express；QClaw 仅可参考 Prompt、工作流和输出格式，
  不作为正式运行时依赖。
- 数据读写通过 service 或 repository 隔离，避免页面直接绑定具体存储方案。
- 将内存 Mock 替换为 HTTP、Hive、SQLite 或云端实现时，尽量保持页面调用契约稳定。

## 4. 代码地图

- `lib/main.dart`：应用启动、依赖实例和启动阶段状态机。
- `lib/pages/`：页面、导航和用户流程。
- `lib/widgets/`：可复用 UI 组件。
- `lib/models/`：正式业务数据结构；`app_models.dart` 提供聚合导出。
- `lib/services/agent_service.dart`：AI 能力边界及 Mock 实现。
- `lib/services/*_service.dart`：用户与宠物等领域服务。
- `lib/services/*_repository.dart`：需要独立持久化的领域数据访问。
- `lib/mock/`：静态演示数据。
- `lib/theme/`：颜色和统一主题。
- `test/widget_test.dart`：核心启动流程和主要交互的 Widget 测试。

新增文件时沿用现有职责划分，不把大型业务逻辑堆进 `main.dart` 或页面 `build`
方法。

## 5. 产品与 UI 原则

- 中文是当前主要界面语言。
- 视觉基调应温柔、简洁、低压，沿用现有柔和色彩、圆角卡片和 Material 3 主题。
- 优先复用 `AppColors`、`AppTheme`、`SoftCard`、`PageHeader` 等既有设计元素。
- AI 输出需要明确、结构化、可操作，避免夸大能力或制造确定性。
- 情绪和健康内容不能替代专业医疗、心理或营养建议。
- 宠物照片用于生成形象前应保留清楚的用户授权说明。
- 新流程需要处理 loading、空状态、错误、取消、重复点击和 Widget 生命周期。
- 异步回调更新 UI 前检查 `mounted`，避免页面退出后的 `setState`。

## 6. 开发约定

- 遵循现有 Dart 风格和 `analysis_options.yaml`。
- 优先做范围明确的小改动，不顺手重构无关模块。
- 结构化数据使用明确的 model，不在页面之间传递松散 Map。
- 使用构造函数注入 service，保持页面可测试。
- Mock 与正式实现使用相同接口，Mock 文案和延迟应稳定、可预测。
- 新增用户可见功能时补充或更新 Widget 测试。
- 修改模型或 service 契约时，检查所有实现、调用方和测试。
- 不提交生成目录，例如 `build/`；不要手动编辑 Flutter 生成文件，除非平台配置
  确实要求。
- 未经明确要求，不覆盖或回退用户已有改动。

## 7. 验证命令

在项目根目录运行：

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

涉及 Web 发布时再运行：

```bash
flutter build web --release
```

只修改 Markdown 时无需运行 Flutter 测试，但应检查文档中的路径、命令和现状是否
与代码一致。若因环境缺失无法执行检查，交付时明确说明。

## 8. 当前已知方向

- 冻结当前前端功能，不继续新增页面、入口或业务能力。
- 本地持久化基础设施和核心数据迁移已完成，继续验证真机重启恢复和数据损坏回退。
- 情绪分析 `HttpAgentService` 边界已完成，下一步由自建后端实现 API 契约。
- iOS 为首发平台，需优先补齐完整 Xcode、CocoaPods、Apple 签名和 TestFlight 环境。
- Android 发布与 Android SDK 安装暂缓，不阻塞当前 iOS 内测。
- 其他真实 AI、图片上传和新功能继续暂缓。
- 实现真实鉴权、错误处理、隐私与数据删除机制。
- 扩大 repository、序列化、迁移和关键用户流程的测试覆盖。

这些是方向，不代表已经承诺的具体排期。MVP 稳定后可以继续迭代新板块，但实现前
必须以用户当次需求为准，不提前恢复灵感创作或塔罗；首页每日运势卡片属于当前范围。

## 9. 记忆维护规则

每次完成以下变化之一时更新本文件：

- 产品定位、核心用户流程或导航发生变化。
- 新增或替换关键 service、repository、后端或存储方案。
- 出现必须长期遵守的安全、隐私、设计或工程决策。
- 某项“当前实现状态”已经失效。
- 用户明确表达了适用于后续任务的稳定偏好。

维护时只保存可复用的事实与决策，不保存密码、Token、私密账号信息、临时调试
输出或未经验证的猜测。对仍不确定的信息标记为“待确认”，不要写成既定事实。

最后更新：2026-06-13
