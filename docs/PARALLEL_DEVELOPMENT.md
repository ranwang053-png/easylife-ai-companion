# Easylife 前后端并行开发

## Single source of truth

`contracts/openapi.yaml` 是唯一接口标准。固定测试数据来自 `contracts/examples/`。
前端、后端不得在实现目录复制并独立维护另一份字段定义或错误码列表。

## Workstreams

### Frontend

第一批任务：

1. 从契约建立认证 DTO 和 service 抽象。
2. 使用固定示例完成手机号、验证码和新用户自动注册流程。
3. 覆盖验证码过期、错误、次数超限、限流和短信服务不可用状态。
4. 保持情绪分析与保存分离。
5. 为固定响应和异常状态建立契约测试。

前端本阶段不接真实短信、数据库或 AI。

### Backend

第一批任务：

1. 按 OpenAPI 建立路由、请求校验和固定响应。
2. 实现固定短信 challenge、会话、情绪分析、同步和注销接口。
3. 通过测试触发机制覆盖契约中的错误码。
4. 禁止记录请求体、手机号、Token、完整情绪原文和用户画像。
5. 后端契约测试通过后，再逐步替换短信、数据库和 AI provider。

固定响应阶段不得绕过 OpenAPI 校验。

## Ownership

| Area | Owner | Write scope |
| --- | --- | --- |
| API 契约 | 三方共同确认 | `contracts/` |
| Flutter | 前端 | `lib/`, `test/`, Flutter dependencies |
| HTTP server | 后端 | `backend/server/` |
| PostgreSQL | 后端 | `backend/database/` |
| 产品决策 | 产品 | `AGENTS.md`, delivery documents |

任何工作流需要修改其他所有者的目录时，应停止并提交契约或架构变更申请。

## Contract tests

前端契约测试至少验证：

- 示例 JSON 能解析为前端 DTO。
- 必填字段缺失或类型错误时进入受控错误状态。
- 所有声明的认证错误码映射到明确页面状态。
- 情绪分析成功不会自动写入日记。
- 用户确认后才调用本地保存和同步队列。

后端契约测试至少验证：

- 路径、方法、状态码、响应字段和错误结构符合 OpenAPI。
- 固定示例通过 Schema 校验。
- 未声明字段和错误码不会返回。
- 日志中不出现手机号、Token、完整情绪文本或用户画像。
- 同一 mutation 重试不会重复创建记录。

## Integration gate

开始联调前必须全部满足：

- OpenAPI lint 通过。
- 前端静态检查和契约测试通过。
- 后端静态检查和契约测试通过。
- 当前契约版本和变更记录一致。
- 测试环境只使用固定响应，或者明确标记已替换的 provider。

联调顺序：

1. 手机号验证码成功流程。
2. 各认证错误状态。
3. 情绪分析成功、超时与服务不可用。
4. 用户确认后的本地保存。
5. 离线 Outbox 和恢复联网后的 push/pull。
6. 单条删除。
7. 注销账号和本机数据清除。

## TestFlight gate

只有以下条件满足后才能进入 TestFlight：

- 联调清单全部通过。
- 真实短信、数据库和 AI provider 已完成各自验收。
- 断网、本地优先和自动同步经过真机测试。
- 账号注销能够撤销会话并进入彻底删除流程。
- 隐私说明与实际采集、保存和删除行为一致。
- 日志抽查确认没有敏感内容。
