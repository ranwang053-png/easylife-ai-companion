# Easylife API Contract Governance

`contracts/openapi.yaml` 是前端、后端和测试共同使用的唯一接口标准。

## Change process

任何以下变化都必须先提交契约变更申请：

- 请求或响应字段新增、删除、改名、类型或语义变化
- HTTP 状态码或业务错误码变化
- 鉴权、幂等、超时、重试或限流规则变化
- 情绪分析、日记保存、长期记忆或同步时机变化
- 数据删除、账号注销或隐私边界变化

变更流程：

1. 使用 `CHANGE_REQUEST_TEMPLATE.md` 写明产品原因和兼容性影响。
2. 产品、前端和后端共同确认。
3. 先修改 `openapi.yaml`、示例和 `CHANGELOG.md`。
4. 契约 lint 通过后，前后端分别更新实现和契约测试。
5. 两端契约测试都通过后才能开始联调。

禁止先修改实现，再让契约追认。

## Compatibility

- V1 允许新增可选字段。
- 删除字段、改变字段类型或语义属于破坏性变更。
- 破坏性变更进入新的主版本路径，例如 `/v2`。
- 客户端不得依赖 OpenAPI 未声明的字段。
- 后端不得返回未在 OpenAPI 声明的业务错误码。

## Review ownership

每次契约变更至少需要以下三方确认：

| Role | Required review |
| --- | --- |
| 产品 | 用户流程、保存时机、隐私和错误体验 |
| 前端 | DTO、状态机、离线行为和兼容性 |
| 后端 | 校验、事务、数据库、限流和安全 |

确认记录写入 `CHANGELOG.md` 对应版本。未完成三方确认的变更不得合并。

## Validation

```bash
npx @redocly/cli lint contracts/openapi.yaml
```

示例 JSON 必须保持可解析，并由前后端契约测试直接读取，避免复制出第二套测试数据。
