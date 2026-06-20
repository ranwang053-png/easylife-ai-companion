# Easylife Database

Easylife 后端数据库使用 PostgreSQL。当前迁移只覆盖第一阶段：

- 中国大陆手机号短信验证码认证
- 用户画像
- 宠物档案
- 情绪日记
- 长期记忆
- 本地优先增量同步
- 用户数据删除和账号注销

饮食与体重数据留到第二阶段，不在本次数据库中建表。

## Apply migration

准备 PostgreSQL 15 或更高版本，并设置连接字符串。迁移不依赖数据库加密扩展，
手机号哈希和加密均由后端应用层完成：

```bash
export DATABASE_URL='postgresql://user:password@localhost:5432/easylife'
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 \
  -f backend/database/migrations/0001_initial.sql
```

迁移完成后运行可回滚的约束测试：

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 \
  -f backend/database/tests/0001_smoke.sql
```

生产环境使用独立的迁移角色。应用运行角色不应拥有创建扩展、删除 Schema 或修改迁移
历史的权限。

## Phone identity

客户端和服务端将手机号规范化为 E.164，例如 `+8613812345678`。

数据库不保存可直接查询的手机号明文：

- `phone_lookup_hash`：使用独立服务端 pepper 计算
  `HMAC-SHA-256(normalizedPhone)`，用于唯一约束和账号查询。
- `phone_ciphertext`：在应用层使用 AEAD 加密，用于确有必要时解密发送短信。
- pepper 和加密密钥保存在部署平台 Secret/KMS 中，不能进入数据库、代码仓库或日志。

`users.phone_lookup_hash` 的唯一约束保证一个中国大陆手机号只能对应一个 Easylife
账号。短信登录验证成功后，后端必须在同一事务中按该值查询或创建用户，以处理并发
验证请求。

## SMS challenges

- 验证码有效期为 5 分钟。
- 60 秒后才能再次发送。
- 同一手机号每小时最多 5 次，每天最多 10 次。
- 同一设备或 IP 每小时最多 20 次。
- 单个 challenge 最多允许 5 次错误；达到上限后设置 `invalidated_at`。
- `code_hash` 使用 challenge ID、验证码和独立 pepper 计算 keyed hash。
- 只保存设备和 IP 的 keyed hash，不保存原始设备标识或 IP。
- 定期删除已经过期、消费或失效的 challenge。

频率限制需要在事务中查询对应索引，并配合 Redis 或数据库 advisory lock 防止并发
绕过。无论手机号是否已注册，发送接口都返回相同结构。

## Local-first sync

客户端先写本地数据库和 Outbox，界面不等待云端。联网后：

1. 以 `mutation_id` 调用 `/v1/sync/push`。
2. 后端在 `sync_mutations` 中保证用户范围内幂等。
3. 成功写入业务表后，在同一事务中追加 `sync_changes`。
4. 客户端通过不透明游标调用 `/v1/sync/pull`。
5. 删除使用 `deleted_at` 墓碑，客户端拉取后同步删除本地数据。

`clientUpdatedAt` 不能用于解决冲突。更新和删除必须比较 `baseVersion`；成功后版本加
一。服务端游标可以编码 `sync_changes.sequence_id`，但客户端不得解析游标。

用户画像不得通过普通同步删除。删除整个用户账号必须使用账号注销流程。

## Emotion boundary

情绪分析 API 是无状态推理：

- 分析结果不写入 `emotion_entries` 或 `memory_notes`。
- 用户点击“记录”后，客户端先保存本地情绪日记和长期记忆。
- 随后将两条 mutation 加入 Outbox，并在联网后同步。
- 未确认、取消或关闭页面的分析结果不得进入数据库。

`memory_notes.source_emotion_entry_id` 使用同用户复合外键，防止记忆引用其他用户的
情绪日记。普通记录删除只更新 `deleted_at`；后台物理删除情绪日记时，其来源记忆也会
级联删除。

## Logging policy

应用日志、访问日志、Tracing 和 `security_events` 禁止记录：

- 手机号和手机号密文
- 短信验证码、验证码哈希或 Token
- 完整情绪原文、伙伴回复或长期记忆正文
- 用户画像字段或完整请求体

允许记录：

- 随机 `request_id`
- 内部 `user_id`
- 接口名、HTTP 状态、错误码和耗时
- AI 模型名、Token 数和供应商请求 ID
- 同步实体类型、数量、版本和 mutation 状态

日志框架必须默认关闭请求体和响应体记录，并对异常对象执行字段白名单序列化。

## Access control

所有业务查询必须同时带 `user_id`。不得只凭客户端提供的实体 ID 查询、修改或删除
数据。服务端从访问令牌获取用户 ID，不信任请求体中的用户标识。

数据库备份、只读副本和对象存储中的宠物图片也必须纳入账号删除流程。
