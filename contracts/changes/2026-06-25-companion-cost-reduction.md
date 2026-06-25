# API Contract Change Request

## Summary

为降低多轮陪伴的模型输出成本，计划在新主版本中用精简陪伴响应替代 V1 的完整单轮情绪分析响应。

## Product reason

陪伴聊天每轮只需要自然回复、最低限度的情绪线索、风险等级和可选服务建议。情绪强度、可能原因和结构化总结应在用户主动保存情绪日记时，根据整轮对话统一生成，不应在每轮重复生成。

## Proposed contract changes

- 保留现有 `POST /v1/emotion/analyze`，不破坏已发布客户端。
- 新增 V2 陪伴回复接口，建议路径为 `POST /v2/companion/respond`。
- V2 响应只包含：
  - `reply`
  - `emotionLabel`，可为空
  - `riskLevel`
  - `serviceSuggestion`，可为空
- 新增独立的 V2 情绪日记整理接口，仅在用户主动保存时调用。
- 日记整理响应包含：
  - `recap`
  - `emotionTags`
  - `trigger`
  - `insight`
  - `nextActions`
  - `closingWords`
- 日期、记录 ID、保存时间和伙伴状态由后端或客户端生成。
- V2 上线并完成客户端迁移后，再单独规划 V1 下线时间。

## Compatibility

- [ ] 向后兼容
- [x] 破坏性变更，需要新主版本

## Data and privacy impact

- 陪伴接口继续保持无状态，不自动保存对话或日记。
- 只有用户主动保存时，完整本轮对话才发送给日记整理接口。
- 不新增高敏字段；日志仍不得记录完整情绪原文和长期记忆正文。

## Client impact

- 新增 V2 DTO 和两个独立调用：陪伴回复、保存日记。
- 移除聊天页面对单轮强度、可能原因、建议和伙伴状态的直接依赖。
- 保存日记成功后继续本地优先写入并加入同步 Outbox。
- 迁移期间保留 V1 回退能力。

## Server impact

- 新增 V2 路由、Schema、固定示例和 Provider adapter。
- 风险分级必须在服务端校验，危机响应不能依赖前端自行推断。
- 日记整理接口需要独立限流、超时和输出校验。
- V1 Provider 和固定响应在迁移期继续保留。

## Approval

- [x] 产品确认
- [ ] 前端确认
- [ ] 后端确认

## Release gates

- [ ] OpenAPI、示例和 CHANGELOG 已更新
- [ ] 契约 lint 通过
- [ ] 前端契约测试通过
- [ ] 后端契约测试通过
- [ ] 联调通过
