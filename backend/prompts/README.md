# Easylife Prompt Library

This directory stores versioned prompt templates for backend AI providers.

Rules:

- Prompts are backend assets. Do not embed API keys or provider secrets here.
- Do not put complete user private text, phone numbers, tokens, or full profile examples in prompt files.
- Keep each prompt versioned with a stable filename, for example `pet_avatar_generation.v1.md`.
- Provider-specific adapters may transform these templates, but product intent and safety rules should stay traceable here.
- If a prompt changes model output shape, update the API contract and examples before implementation.

Current prompts:

- `companion_reply.v1.md`: 低成本多轮陪伴回复；后端先用规则注入 `personaSummary`、`replyIntent` 和 `questionAllowed`，模型生成默认简短、必要时可稍微展开的自然回复、一个可选情绪标签、风险等级和可选服务建议。
- `daily_fortune_generation.v1.md`: 今日运势生成；整体解读限制为 180-260 字，不重复生成整体分数解释。
- `diet_advice_planning.v1.md`: 基于后端饮食摘要生成最多两条调整建议和明日轻量餐单。
- `diet_review.v1.md`: 只生成上一期、本期的语言总结和下一期建议；统计值全部由后端计算。
- `emotion_journal_summary.v1.md`: 用户主动保存后，将完整陪伴对话整理成结构化情绪日记卡片。
- `food_vision_recognition.v1.md`: 只返回可见食物、估计份量和单项置信度。
- `long_term_memory_extraction.v1.md`: 每次最多提炼三条低敏、稳定、可复用且带分类的长期记忆候选；泛泛情绪不入库。
- `nutrition_analysis.v1.md`: 按食物返回单值热量和营养估算；总计、复核状态和贴纸展示由代码生成。
- `pet_avatar_generation.v1.md`: 伙伴形象生成。
- `user_profile_summary.v1.md`: 后端规则拼装规范，不进行实时模型调用。

## Cost control

- 模型只生成需要语义判断或自然语言表达的字段。
- 日期、ID、状态映射、数值求和、计数、排序、标题、颜色、emoji 和 UI 文案优先由代码生成。
- 不要求模型回显调用方已经持有的输入字段。
- 用户画像上下文默认由后端规则筛选和限长；只有记忆超过阈值时才允许异步压缩。
- 破坏现有 API 输出结构的 Prompt 变化必须先进入新主版本契约，不直接修改冻结的 V1。
