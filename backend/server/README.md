# Easylife Fixed API

这是基于 `contracts/openapi.yaml` V1.1.0 的并行开发后端。当前只提供固定响应，
不发送真实短信、不调用真实 AI，也不连接 PostgreSQL。

## Scope

已实现：

- `GET /v1/health`
- `POST /v1/auth/sms/codes`
- `POST /v1/auth/sms/verify`
- `POST /v1/auth/token/refresh`
- `POST /v1/auth/logout`
- `POST /v1/emotion/analyze`
- `POST /v1/sync/push`
- `GET /v1/sync/pull`
- `DELETE /v1/me/account`

成功响应来自 OpenAPI 契约示例。请求体使用同一份 OpenAPI Schema 校验。
受保护接口只接受环境变量配置的固定 `Bearer` Token，仅用于前后端联调。

情绪分析通过 `EmotionProvider` 接口调用。当前实现为
`FixedEmotionProvider`；未来接入真实模型时新增 Provider，不应把模型 SDK、Prompt
或密钥放进路由。

## Run

```bash
cd backend/server
npm install
cp .env.example .env
npm run dev
```

默认监听 `http://127.0.0.1:3000`。健康检查：

```bash
curl http://127.0.0.1:3000/v1/health
```

运行验证：

```bash
npm run typecheck
npm run build
npm test
```

## Test errors

测试错误触发器默认关闭。仅在自动测试或隔离的本地环境设置：

```bash
ENABLE_TEST_TRIGGERS=true
```

随后可发送：

```text
X-Easylife-Test-Error: RATE_LIMITED
```

支持的值取自当前路由在 OpenAPI 中声明的错误码。短信验证还支持：

```text
X-Easylife-Test-Sms-Purpose: account_deletion
```

用于取得注销验证固定响应。这些请求头在 `ENABLE_TEST_TRIGGERS=false` 时会被忽略，
不得在共享测试环境或生产环境开启。

## Logging

服务只记录以下白名单字段：

- 随机 `requestId`
- HTTP method
- route
- status
- duration

禁止记录请求体、响应体、手机号、Authorization、Token、完整情绪原文、长期记忆、
用户画像和短信验证码。Express 本身没有启用访问日志中间件，
`LOG_HTTP_BODIES` 必须保持 `false`。

## Current limitations

- 没有真实验证码状态、频率限制或自动注册持久化。
- 没有真实 Token 签发、轮换和撤销。
- 同步接口不写数据库，固定返回契约示例。
- 情绪分析是无状态固定响应，不会保存情绪日记或长期记忆。
- 注销接口只返回固定的异步任务响应，不执行物理删除。

这些能力只能在保持 OpenAPI V1.1.0 兼容的前提下替换。字段、错误码和保存时机变化
必须先更新共同确认的契约与变更记录。
