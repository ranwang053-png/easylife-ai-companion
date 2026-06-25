# Easylife API

这是基于 `contracts/openapi.yaml` V1.1.0 的后端。认证模块已经支持 PostgreSQL
真实用户、短信 challenge、数据库会话、刷新令牌轮换、当前设备退出和账号注销任务。
未配置 `DATABASE_URL` 时，仅在开发和测试环境使用固定认证夹具。

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

请求体继续使用 OpenAPI Schema 校验，请求字段、响应结构和错误码保持 V1.1.0
兼容。生产环境必须配置数据库和认证密钥，不能使用固定 Token 启动。

情绪分析通过 `EmotionProvider` 接口调用。当前实现为
`FixedEmotionProvider`；未来接入真实模型时新增 Provider，不应把模型 SDK、Prompt
或密钥放进路由。

## Run

```bash
cd backend/server
npm install
cp .env.example .env
npm run migrate
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

API 和后台任务分别运行：

```bash
npm run start
npm run start:worker
```

`npm run migrate` 使用数据库 advisory lock、版本表和 SHA-256 校验和，只应用尚未执行
的迁移；已经登记的迁移文件若被修改会拒绝继续执行。

开发环境使用 `npm run dev` 和 `npm run dev:worker`。生产环境必须同时运行 API 和
worker，否则账号注销任务只会停留在队列中。

设置 `TEST_DATABASE_URL` 后，`npm test` 会额外运行真实 PostgreSQL 认证集成测试；
未设置时只跳过该测试文件中的数据库用例。

## Authentication

- 验证码有效 5 分钟，同一 challenge 最多错误 5 次。
- 发送频率按手机号、设备和 IP 的 keyed hash 限制。
- 手机号使用 HMAC 盲索引查询，并使用 AES-256-GCM 密文保存。
- Access Token 为 15 分钟 JWT，但每次受保护请求仍会检查数据库会话状态。
- Refresh Token 为 30 天随机不透明令牌，数据库只保存 keyed hash。
- Refresh Token 每次使用后原子轮换；重放旧 Token 会撤销对应会话。
- Access Token 带 `kid`；`ACCESS_TOKEN_PREVIOUS_KEYS` 可在密钥轮换期间继续验证
  尚未过期的旧 Token。
- 退出接口只撤销当前设备会话，并保持幂等。
- 登录、刷新、退出、验证码失败和注销会写入不含手机号、验证码或 Token 的安全事件。
- 账号注销沿用二次短信验证，成功后立即撤销全部会话并创建异步删除任务。worker
  使用数据库租约和 `SKIP LOCKED` 领取任务，失败后指数退避重试。

短信通过 `SMS_PROVIDER_URL` 调用 HTTPS 网关。网关接收：

```json
{
  "phone": "+8613812345678",
  "code": "123456",
  "purpose": "login"
}
```

请求使用 `SMS_PROVIDER_TOKEN` 作为 Bearer Token，并用 challenge ID 作为
`Idempotency-Key`。网关对成功请求可返回 `{"messageId":"..."}`。后端会对网络错误、
429 和 5xx 做有限重试；其他 4xx 不重试。若使用阿里云、腾讯云等供应商，应在网关内
完成供应商签名和模板映射，不把供应商密钥放进 Flutter 客户端。

## Account deletion worker

worker 在物理删除前调用 `ACCOUNT_DELETION_CLEANUP_URL`，请求只包含内部用户 ID 和
注销任务 ID。外部清理服务必须保证幂等，并负责对象存储、缓存、分析系统和第三方
供应商数据。外部清理成功后，worker 才调用数据库删除函数。

当确认当前环境的用户数据全部位于 PostgreSQL 时，可显式设置：

```bash
ACCOUNT_DELETION_ALLOW_DATABASE_ONLY=true
```

worker 还会周期清理过期验证码、注销凭证、旧会话、刷新令牌历史和过期安全事件。

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

- 同步接口不写数据库，固定返回契约示例。
- 情绪分析是无状态固定响应，不会保存情绪日记或长期记忆。
- 真实短信能否发送取决于 `SMS_PROVIDER_URL` 对应网关及供应商账号是否已配置和联调。
- 对象存储、缓存和第三方数据的实际删除取决于
  `ACCOUNT_DELETION_CLEANUP_URL` 对应清理服务。

这些能力只能在保持 OpenAPI V1.1.0 兼容的前提下替换。字段、错误码和保存时机变化
必须先更新共同确认的契约与变更记录。
