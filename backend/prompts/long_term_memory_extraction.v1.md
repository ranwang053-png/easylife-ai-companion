# Long Term Memory Extraction Prompt V1

## Role

从用户已经确认保存的内容中，提炼少量低敏感、稳定、可复用的长期记忆候选。
长期记忆不是情绪日记摘录，只保存以后陪伴、饮食建议或个性化回应能复用的信息。

## Input

- 来源类型：`{{source_type}}`
- 已确认内容：`{{source_content}}`
- 已有记忆：`{{existing_memories}}`

## Rules

- 只使用用户确认保存的内容。
- 每次最多 3 条，每条不超过 80 字。
- 一次性事件、重复内容和高敏感信息不得保存。
- 不引用原文，不保存完整日记、饮食记录或用户画像。
- 情绪内容只能在包含原因、情境、偏好、习惯或阶段性压力来源时保存。
- 如果用户只是表达“心情不好”“有点难过”“焦虑”“很累”，但没有原因、背景或可复用偏好，返回空数组。
- 健康相关内容只能写成“用户提到/自述”，不得写成医学诊断或确定事实。
- 没有合适内容时返回空数组。
- 只输出合法 JSON。

## Memory Types

- `emotional_sensitivity`: 用户在特定情境下容易出现的情绪反应。例如连续加班后容易疲惫和自责。
- `coping_strategy`: 对用户有效的自我调节方式。例如散步、听轻音乐能帮助用户慢慢放松。
- `current_focus`: 用户当前阶段的重要任务、目标或压力来源。例如最近在准备作品集和面试。
- `communication_preference`: 用户希望被回应的方式。例如压力大时希望先被倾听，而不是立刻收到建议。
- `lifestyle_habit`: 用户稳定出现的日常行为和偏好。例如早餐偏简单，下午容易想喝咖啡。
- `health_context`: 用户自述的身体与健康线索。例如用户提到自己有胃炎/胃痛，饮食建议需要更温和。
- `work_study_context`: 用户当前工作、实习或学习节奏。例如实习选择让用户感到不确定。
- `boundary`: 用户明确表达的边界、禁忌或不喜欢的回应方式。

## Examples

- “我有胃炎，最近又胃痛” -> 保存 `health_context`: “用户提到自己有胃炎/胃痛，饮食建议需要更温和”
- “最近因为实习和工作选择很焦虑” -> 保存 `current_focus`: “用户近期因实习和工作选择感到困惑”
- “压力大的时候我只想先被听见，不想马上听建议” -> 保存 `communication_preference`: “压力大时希望先被倾听，而不是立刻收到建议”
- “今天心情不好” -> 不保存

## Output

```json
{
  "memory_candidates": [
    {
      "type": "emotional_sensitivity/coping_strategy/current_focus/communication_preference/lifestyle_habit/health_context/work_study_context/boundary",
      "content": "低敏、稳定、可复用的记忆候选",
      "usage": "companion/diet/fortune/profile"
    }
  ]
}
```

来源类型由调用方持有，不要求模型回显。候选置信度由后端规则、重复检查或人工确认流程处理，不采用模型自报置信度。
