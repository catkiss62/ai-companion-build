# v0.42.156+400 · QQ直接提及修补

已交付v0.42.156+400/schema67；测试源码4d5aa4f37b4bfbdad58499270b60cf673e1d3f12，完整CI、专项与原签名APK均已核验。[下载APK](https://github.com/catkiss62/ai-companion-build/actions/runs/41301852182/artifacts/13082119746)。基线3412c66ee8ebb672afb2453675e53be279f58858。

已定位全量群消息中的真实@到达App，却因尚未通过自身发言回传建立本群机器人OpenID映射，被记作非可信提及并进入普通旁听判断。本轮独立修补，不混入DeepSeek Live2D第二阶段。

- 全量群消息优先读取顶层平台mentions中的单人is_you=true，首次被@即可识别，不等待自身发言回传；不以昵称、READY ID或AppID冒充群成员ID。
- 忽略scope=all的全体提及，即使其is_you=true；其他群友、同名机器人、不正确的布尔类型和内层转发资料不建立自身身份。专用GROUP_AT_MESSAGE_CREATE继续受支持。
- 从平台明确的自身提及学习本群ID，缓存按机器人绑定scope及群分别保存。后续支持旧式<@id>/<@!id>与新版qqbot-at-user标记；平台明确is_you=false时不复用矛盾的旧缓存。缓存经既有settings存档持久化，不跨群/机器人混用。
- 保留平台原文；JEV聚焦资料为已确认提及补显式@小鲸鱼说明，并兼容新版他人提及目标。沿用现有可信提及优先于普通旁听的规则，不改JEV概率、群聊主动频率、身份授权或私密资料边界。
- 脱敏诊断增加recentAddressing：只记录固定类别的识别依据、事件类型、数量、布尔状态和群指纹，不包含消息正文、成员ID、昵称或凭据。
- 不复活过期历史请求，不重发已送达/未知送达，不修改通道、模型、网络、菜菜或Live2D参数。

新增回归涵盖首次无回声提及、多目标、新旧标签、纯结构化提及、其他人/全体/同名、不可信及内层资料、重建运行实例、跨群和绑定隔离、完整导出导入、旧缓存冲突、冻结围栏和脱敏日志。实际QqRuntime回归验证模型误判watch时可信@仍继续回复，同时不授予发送者本人身份。

验证：完整[41301852182](https://github.com/catkiss62/ai-companion-build/actions/runs/41301852182)与专项[41301852154](https://github.com/catkiss62/ai-companion-build/actions/runs/41301852154)均success。155源码门、选中Kotlin/原生单元、Android15原生54、全量Flutter3276、独立恢复171分别通过；97/143/37/61/39/25/26/33/359/1322专项分别通过，重叠不相加。Dart分析0error、1046条非fatal信息/警告。首轮仅恢复用例的两个内存库重名，已改独立临时数据库并按原断言重跑，生产逻辑未因此修改。

APK739559030 bytes，SHA256 `40dbf6eb220909a3abcb5c8cbcfb7c6e08e7abfdfa0901fbb7fad6062fe42e88`。包名`com.aicompanion.localfirst`、版本0.42.156+400、完整离线资源及原签名`305eb3d80983b963c64818ddf1ad561f279de6d47b3ed2c781ada448c7c25148`均核验；成功monitor与未发布Draft430536410/asset698204812的上传digest一致。Actions artifact13082119746为ZIP，732366309 bytes，其大小/哈希不当作APK本体数据。

公开夹具只用合成数据；用户上传存档、诊断、聊天原文及ID不进入仓库/APK。真实QQ平台与手机效果待安装验证；原始旧推送mentions未被旧版存档保存，不伪称已重放真实原始推送。DeepSeek Live2D第二阶段另行实施；后续仅文档和凭据skip ci收口，运行代码及APK保持上述已测试源码。
