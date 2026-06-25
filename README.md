# Easylife AI 生活陪伴 App

Flutter 手机端 MVP，当前聚焦用户画像、桌宠陪伴、每日运势、情绪记录、饮食体重，
并提供本地持久化、作品集演示模式和 PostgreSQL 认证后端。

完整交付说明见 [`DELIVERY.md`](DELIVERY.md)。

## 目录

- `lib/models`：页面数据模型
- `lib/pages`：页面与 App Shell
- `lib/widgets`：通用卡片、桌宠、快捷操作组件
- `lib/services`：未来 Agent / 后端接口
- `lib/theme`：颜色与主题
- `lib/mock`：本地 Mock 数据

## 首次运行

```bash
flutter pub get
flutter run
```

## 检查

```bash
flutter analyze
flutter test
```

## 作品集演示构建

```bash
flutter build web --release \
  --dart-define=EASYLIFE_DEMO_MODE=true
```

演示模式不要求手机号和短信验证码，数据只保存在当前设备。正式构建默认不启用该开关。

## Agent 架构

```text
Flutter App
    ↓
AgentService
    ↓
MockAgentService / Node.js + Express API
```

页面只调用 `AgentService` 的结构化业务方法，不包含 Prompt 或 AI 判断逻辑。
当前 MVP 首页包含每日运势卡片，不包含灵感创作和塔罗。架构保留继续迭代的空间，
但不提前维护未进入 MVP 的领域代码。

自 2026-06-14 起解除前端功能冻结。现有页面可以优化布局、配色、动效和组件，也可
在保持现有功能与主导航不变的前提下全面重新设计 UI。新增功能需由用户明确确认，并
同步更新产品范围、架构、测试和文档。

当前生产入口已经使用 `shared_preferences` 保存用户、宠物、情绪、饮食和体重
数据。情绪分析可通过自建后端接入：

```bash
flutter run \
  --dart-define=EASYLIFE_API_BASE_URL=https://api.example.com
```

未配置或后端失败时自动回退本地 Mock。后端认证、数据库迁移与运行说明见
[`backend/server/README.md`](backend/server/README.md)，接口契约见
[`docs/AI_BACKEND.md`](docs/AI_BACKEND.md)，打包验收见
[`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md)。
