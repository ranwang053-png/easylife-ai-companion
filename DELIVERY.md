# Easylife Flutter MVP 交付说明

## 1. MVP 范围

当前版本包含四项核心能力和首页每日运势展示：

1. 用户画像
2. 桌宠陪伴
3. 情绪记录
4. 饮食与体重记录

首页每日运势卡片包含整体运势、幸运色、幸运食物、幸运数字、幸运花，
事业/财富/爱情/人际分数、建议和避免。
灵感创作与塔罗不属于当前 MVP。

自 2026-06-13 起，当前前端范围冻结，不再新增页面、导航入口、首页卡片或业务模块。
下一交付阶段集中解决本地数据持久化。
首发平台确定为 iOS，当前打包和内测工作以真机与 TestFlight 为目标；Android 暂缓。

## 2. 当前流程

```text
登录 / 注册
    -> 填写用户基础信息
    -> 主 App
        -> 首页
        -> 陪伴
        -> 饮食
        -> 我的
```

- 首页：桌宠互动、心情输入、每日运势和今日记录状态。
- 陪伴：情绪输入、Mock 情绪分析、陪伴回复、建议和历史。
- 饮食：食物记录、Mock 热量估算、食物贴纸、体重记录和趋势。
- 我的：用户画像、宠物档案、饮食偏好、目标和陪伴偏好。

## 3. 核心目录

```text
lib/
├── main.dart
├── mock/
│   ├── app_mock.dart
│   └── dashboard_mock.dart
├── models/
│   ├── app_models.dart
│   ├── dashboard_models.dart
│   ├── meal_record.dart
│   ├── models.dart
│   ├── pet_mood_log.dart
│   ├── pet_profile.dart
│   ├── user_profile.dart
│   └── weight_record.dart
├── pages/
│   ├── app_shell.dart
│   ├── companion_page.dart
│   ├── dashboard_page.dart
│   ├── health_page.dart
│   ├── my_page.dart
│   ├── settings_page.dart
│   └── 登录、用户信息、宠物档案与饮食子流程页面
├── services/
│   ├── agent_service.dart
│   ├── pet_profile_service.dart
│   └── user_profile_service.dart
├── theme/
└── widgets/
```

## 4. Agent 架构

```text
Flutter Page
    -> AgentService
        -> MockAgentService（当前）
        -> HttpAgentService（未来）
            -> Node.js / Express API
                -> AI Model + Database
```

当前 `AgentService` 只提供 MVP 所需能力：

- 情绪分析与桌宠回复
- 文本食物热量估算
- 图片或配料输入的食物热量估算
- 饮食计划建议
- 宠物形象生成占位
- 用户画像同步

页面不包含 Prompt 或模型供应商逻辑。模型 API Key 必须保存在未来的自建后端，
不得放入 Flutter 客户端。

## 5. 数据状态

- 生产入口使用 `shared_preferences` 保存用户画像、宠物档案、情绪、饮食、体重
  和引导状态。
- `LocalStore` 隔离底层键值存储，`JournalRepository` 管理日志型数据。
- Widget 测试使用内存 store，避免测试之间相互污染。
- 本地数据采用 JSON；解析失败时回退到可用初始数据。
- 情绪分析可通过 `EASYLIFE_API_BASE_URL` 调用自建后端，失败时回退本地 Mock。
- 其他 AI 能力仍由 `MockAgentService` 提供。

## 6. 本地存储阶段

按以下顺序推进，不并行扩展前端功能：

1. 已为业务 models 增加 JSON 序列化和兼容默认值。
2. 已建立统一的本地存储接口、异常恢复和测试替身。
3. 已持久化用户画像与宠物档案，并保持现有 service 调用契约。
4. 已为情绪、饮食和体重建立 repository，替换页面内存列表。
5. 已覆盖序列化、恢复、HTTP 成功和失败回退测试；真机重启恢复待人工验收。

技术选型应同时支持当前 Flutter 平台与 Web 预览；确定实现前需验证依赖的平台支持、
迁移能力和测试体验。

## 7. 运行与检查

```bash
flutter pub get
flutter run
```

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Web 发布构建：

```bash
flutter build web --release
```

## 8. 后续方向

1. 在真机验证 App 重启后的数据恢复。
2. 按 `docs/AI_BACKEND.md` 实现情绪分析后端。
3. 补齐 Xcode、CocoaPods、Apple 签名与 TestFlight 环境。
4. 完成 `docs/RELEASE_CHECKLIST.md` 中的人工验收。
5. 未经新的明确产品决策，不解除前端冻结。

最后更新：2026-06-13
