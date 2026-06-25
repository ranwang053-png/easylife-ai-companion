# Account Deletion Runbook

账号注销使用二次短信验证。验证成功后服务端签发 10 分钟有效、只可使用一次并绑定
用户与设备的注销凭证。注销接口消费凭证后，在同一个事务中调用：

```sql
SELECT begin_account_deletion(
  'USER_UUID',
  'DELETION_REQUEST_UUID'
);
```

该函数会：

1. 将账号标记为 `deletion_pending`。
2. 记录注销时间。
3. 撤销该用户所有登录会话。
4. 创建异步删除任务。

客户端收到 `202` 后必须立即停止同步，删除 Keychain 中的 Token，并清除本机用户
画像、宠物档案、情绪日记、长期记忆、Outbox 和同步游标。

`backend/server/src/worker.ts` 使用 `FOR UPDATE SKIP LOCKED`、worker 租约和指数退避
消费任务。外部文件、缓存和供应商数据清理成功后，在事务中调用：

```sql
SELECT purge_deleted_account('DELETION_REQUEST_UUID');
```

删除 `users` 会通过外键级联物理删除：

- 登录会话
- 用户画像
- 宠物档案
- 情绪日记
- 长期记忆
- 同步变更
- 幂等 mutation 记录

删除函数还会按手机号盲索引删除对应的短信 challenge，避免验证码表继续保留手机号
密文。

`account_deletion_requests` 保留不含手机号和用户内容的完成证明，其 `user_id` 会变为
空。`security_events.user_id` 同样会变为空。

物理删除前还必须清理数据库以外的数据：

- 宠物原图与生成图片
- Redis 验证码、限流和会话缓存
- 搜索索引或向量数据库
- AI 供应商可能保存的数据
- 分析仓库中的用户级数据
- 数据库备份中的过期副本

若外部清理失败，将任务标记为 `failed` 并写入非敏感 `failure_code`。不得在失败原因
中写入手机号、情绪原文、用户画像或 Token。

生产环境必须运行独立 worker 进程。只有确认不存在数据库外用户数据时，才允许设置
`ACCOUNT_DELETION_ALLOW_DATABASE_ONLY=true`。
