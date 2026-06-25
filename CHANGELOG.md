# Changelog

## v0.3.0-portfolio - 2026-06-25

### Added

- 作品集演示模式，无需短信认证即可进入本地 App。
- PostgreSQL 认证后端、短信 challenge、会话校验、刷新令牌轮换和账号注销 worker。
- 用户可管理的长期记忆页面。
- 日、周、月饮食回顾与轻量建议。
- 版本化 AI Prompt 库和成本控制规则。

### Changed

- 陪伴页改为朋友式多轮对话，仅在用户确认后生成情绪日记。
- 每日运势增加分项解释和完整解读页面，并精简模型输出。
- 饮食记录、体重入口、用户画像及地区和星座选择体验完成一轮修复。
- 正式界面移除实现态和测试态文案。

### Verification

- Flutter analyze and test suite.
- Flutter release web build with portfolio demo mode.
- Backend TypeScript typecheck, build, contract tests and auth tests.
- OpenAPI lint and JSON prompt validation.
