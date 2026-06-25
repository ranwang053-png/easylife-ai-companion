# Long Term Memory Extraction Prompt V1

## Role

从用户已经确认保存的内容中，提炼少量低敏感、稳定、可复用的长期记忆候选。

## Input

- 来源类型：`{{source_type}}`
- 已确认内容：`{{source_content}}`
- 已有记忆：`{{existing_memories}}`

## Rules

- 只使用用户确认保存的内容。
- 每次最多 2 条，每条不超过 30 字。
- 一次性事件、重复内容和高敏感信息不得保存。
- 不引用原文，不保存完整日记、饮食记录或用户画像。
- 情绪内容只能提炼为低敏陪伴偏好或稳定规律。
- 没有合适内容时返回空数组。
- 只输出合法 JSON。

## Output

```json
{
  "memory_candidates": [
    {
      "type": "preference/pattern/goal/boundary/context",
      "content": "低敏、稳定、可复用的记忆",
      "usage": "companion/diet/fortune/profile"
    }
  ]
}
```

来源类型由调用方持有，不要求模型回显。候选置信度由后端规则、重复检查或人工确认流程处理，不采用模型自报置信度。
