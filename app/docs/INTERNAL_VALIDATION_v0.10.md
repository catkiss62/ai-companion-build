# Internal Validation · v0.10

当前环境仍没有 Flutter / Dart / Android SDK，因此本文件严格区分“源码级验证”和“真实 Flutter/Android 运行验证”。

## 本轮已实际执行

- 工程文件：166。
- Dart 源/测试合计：80。
- Kotlin：15。
- Dart 测试文件：17。
- Dart relative import 路径检查：通过，0 缺失。
- Dart/Kotlin 字符串与注释排除后的括号结构扫描：通过。
- `pubspec.yaml` / `analysis_options.yaml`：YAML 解析通过。
- Android XML：全部解析通过。
- 包版本：`0.10.0+10`。
- 六层默认规则：6/6 存在；旧小说 600 字硬门槛、未成年成人化条款、隐藏 AI 身份条款不在 Companion 默认规则中。
- SQLite schema v8 -> v9 迁移模拟：通过。
  - thoughts：`topic_key / merged_count / last_merged_at / snoozed_until`
  - unfinished_threads：`topic_key`
  - proactive_feedback：`topic_key / thread_id / response_quality / outcome / outcome_score / processed_at`
- 旧 proactive feedback 回填模拟：
  - 已回复 -> `response_received`
  - 未回复超时 -> `no_response`
  - 未处理 -> `pending`
  通过。
- Thought / unfinished thread / proactive outcome 的源代码一致性检查：通过。
  - “回复了”不会自动等价于 resolved。
  - deferred / engaged / acknowledged / redirected 不允许 contradictory thread resolve。
  - dismissed 不允许被误写为 resolved。
  - resolved / dismissed 可同时沉降同 `topic_key` 的相关 Thought。
  - 普通后续聊天 resolve 某个 unfinished topic 时，同 topic Thought 也会被满足，避免以后再问已经完成的事情。
- 用户自己在真实 conversation 中重新提起被 snooze 的主题可以重新激活；self-drive / perception 不会自动解除该 snooze。
- Thought 长期去重：同 drive + 同 topic 优先；无 topic 仅允许高文本相似度；不同 drive 不自动合并。
- ChatController 已确认不再把每一句普通用户消息直接持久化为 Thought。
- v0.9 -> v0.10 TTS/native/model/runtime：37 个文件，文件列表一致、逐文件 SHA-256 全部一致，0 缺失 / 0 新增 / 0 改动。

## 本轮发现并修复的实际源码问题

- `recentConversationSummaries()` 曾残留重复 positional query 参数，属于可能直接影响 Dart 编译的问题；已修复。
- proactive outcome 与 thread proposal 加入强一致性保护，避免“晚点再说”却被同时标记为 resolved，以及“别再提”被错误记成普通 resolved。
- v8 proactive feedback 升级到 v9 时增加历史状态回填，避免旧回应记录全部变成 pending。

## 当前环境仍未执行

- `flutter analyze`
- `flutter test`
- Gradle APK 构建
- Android 真机数据库升级
- 后台调度 / 通知 / Overlay / Nearby 真机行为
- Bert-VITS2 / MNN 实际发声

这些继续保留到真正需要完整工具链或真人感知的测试节点，不要求每个源码版本都让用户手动测试。
