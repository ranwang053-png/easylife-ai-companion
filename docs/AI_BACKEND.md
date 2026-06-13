# Easylife 情绪分析 API 契约

当前唯一预留的真实 AI 能力是情绪分析。Flutter 客户端不保存模型 API Key，
只调用自建 HTTPS 后端。

## 推荐实施顺序

1. 建立一个独立的 Node.js / Express 服务，只实现健康检查和本页约定的情绪接口。
2. 先用固定 JSON 响应打通 Flutter、真机网络和异常回退，再接入模型。
3. 模型调用只发生在服务端，并强制输出本页六个字段。
4. 部署为 HTTPS 服务，配置超时、限流、请求体大小限制和脱敏日志。
5. 使用 TestFlight 构建参数注入服务地址，不把 API Key 或模型凭证传入 Flutter。

建议的最小环境变量：

```text
PORT=3000
AI_API_KEY=服务端模型密钥
AI_MODEL=服务端选用的模型
ALLOWED_ORIGINS=允许访问的 Web 测试域名
```

`AI_API_KEY` 只保存在后端部署平台的 Secret 中，不提交到 Git，也不写入
`--dart-define`。

## 启用方式

构建或运行时传入后端地址：

```bash
flutter run \
  --dart-define=EASYLIFE_API_BASE_URL=https://api.example.com
```

未配置地址、请求超时、返回非 2xx 或响应格式错误时，客户端自动回退到本地
`MockAgentService`，保证内测流程可继续使用。

iOS 真机或 TestFlight 构建示例：

```bash
flutter build ipa \
  --release \
  --dart-define=EASYLIFE_API_BASE_URL=https://api.example.com
```

## 请求

```http
POST /v1/emotion/analyze
Content-Type: application/json
```

```json
{
  "text": "今天有一点累",
  "profile": {
    "nickname": "小满",
    "birthday": "1998-06-16T00:00:00.000",
    "goals": ["规律作息"]
  }
}
```

`profile` 使用 `UserProfile.toJson()` 的完整结构。后端不得信任客户端字段，需限制
请求体大小、过滤日志中的个人信息，并在服务端保存模型凭证。

## 响应

```json
{
  "label": "疲惫",
  "intensity": 72,
  "possibleReason": "持续消耗了较多精力。",
  "petSuggestion": "今晚优先休息。",
  "petReply": "先靠一会儿，我陪你慢下来。",
  "petStatus": "陪伴中"
}
```

要求：

- `intensity` 为 `0-100`。
- 六个字段必须全部返回。
- 对 `text` 设置合理长度上限，空文本返回 `400`。
- 模型输出必须经过服务端 schema 校验，不能把未经验证的模型原文直接返回客户端。
- 不在日志中记录完整情绪文本、生日或其他用户画像字段。
- 返回内容不得进行医学诊断；高风险表达应返回温和的求助提示，而不是确定性判断。
- Web 内测环境需要配置允许目标站点访问的 CORS。
- 生产环境只使用 HTTPS，并配置超时、限流、鉴权和请求追踪。
