# User Profile Context Assembly V1

## Decision

MVP 不为每次 AI 请求实时调用模型生成用户画像摘要。用户设置、结构化偏好和带 `usage` 的长期记忆由后端按规则筛选、合并和限长，以减少成本、延迟与画像漂移。

## Input Sources

- 用户明确设置
- 饮食偏好与忌口
- 低敏长期记忆
- 当前能力名称：`companion / diet / fortune / profile`

## Assembly Rules

1. 用户设置优先级最高。
2. 只选择 `usage` 与当前能力匹配的长期记忆。
3. 去重后最多保留 5 条，每条最多 30 字。
4. 不传手机号、地址、精确位置、Token、验证码或完整原文。
5. 不传具体创伤、病史、诊断、用药、财务和亲密关系细节。
6. 不根据 MBTI 生成额外人格判断。
7. 信息冲突时采用更保守、更少打扰的设置。

## Backend Output

该结构由后端代码生成，不调用模型：

```json
{
  "preferred_style": [],
  "avoid_style": [],
  "diet_preferences": [],
  "diet_restrictions": [],
  "active_goals": [],
  "relevant_memories": []
}
```

只有当长期记忆数量超过后端阈值时，才允许异步执行单独的压缩任务；压缩结果不得覆盖用户明确设置。
