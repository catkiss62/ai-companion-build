# QQ 私聊首版：隔离接入、只读记忆

状态：v0.42.135+379 已实现并完成完整 CI，原签名 APK 已取回、合并和校验。CI PASSED / APK READY / TRUE DEVICE PENDING / LIVE QQ PENDING。尚未连接真实 QQ 账号、运行手机实测或调用真实付费模型；自动通过不等于腾讯实网与 HyperOS 长期后台已验收。七类大检查按用户最新决定后移，旧偶发闪退仍保留设备取证。


## 最终交付与证据

- APK 运行源码：`f2e67195bd128ce643a1f1c526c94db6b1b56c75`，tree `1194d7d6255f87ce17974c02fa8ca5775a78ca49`。其后的导出提交 `0d87d5b0` 只改传输工作流/请求，未改 App 代码；文档提交亦不重建或重签。
- [完整CI 40183369738](https://github.com/catkiss62/ai-companion-build/actions/runs/40183369738) 成功：154 项源码门、Kotlin（已包含QQ Service过滤项）、2707 项全量 Flutter、170 项存档/作品恢复、Android15基础原生回归、APK资源、原签名及实际包名/版本检查全部通过。构建 job `121140268089`，原生 job `121138943250`。
- [专项CI 40183369812](https://github.com/catkiss62/ai-companion-build/actions/runs/40183369812) 成功：Dart分析无error、仍有866项非fatal提示；1148项专项通过，其中14项本轮QQ/只读边界测试。真实本地HTTP/WebSocket不等于真实腾讯服务器联调。
- 原包：`com.aicompanion.localfirst`，`0.42.135+379`，738996466 bytes；APK SHA-256 `550f42e400f75f542411f68fae14eab3961da36a2eba7b82efe298a5a939231d`；既有签名证书 SHA-256 `305eb3d80983b963c64818ddf1ad561f279de6d47b3ed2c781ada448c7c25148`。
- 原包保留在[未发布测试Draft 423295505](https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-4a7f3e214b8fa4af0b61)，[APK直链（需所有者登录）](https://github.com/catkiss62/ai-companion-build/releases/download/untagged-4a7f3e214b8fa4af0b61/AI-Companion-v0.42.135-379-QQ-Private-V1-APK.apk)。未合并main、未正式发布。
- [导出40197042095](https://github.com/catkiss62/ai-companion-build/actions/runs/40197042095) 核验成功源运行后将原APK分为三段；下载后逐ZIP、逐段及整包SHA全部匹配，并通过APK ZIP完整性检查。因导出提交只包含传输文件而取消的重复CI不是应用CI失败。安装包超过512MiB单文件传输上限，分段仅用于取回，最终提供原始单一APK。

首轮真机建议：更多→QQ私聊·测试版，填官方机器人AppID/Secret，腾讯平台选择WebSocket并允许本人使用；保存启动后用本人QQ发送一次性绑定命令，再发纯文字及与旧记忆相关的话题。关闭悬浮球后验证QQ仍连接；观察主App聊天、记忆和成长无新增QQ条目，最后关闭QQ连接。图片/语音/引用会收到首版未接入说明，不据此当作媒体已完成。切网/锁屏/系统回收、真实权限或API差异、语气及耗电留待真机反馈。

## 本轮授权与范围

用户希望先跑通本人私聊，QQ 接入应像插件一样独立维护。首版只读取已有记忆，不做 QQ 记忆提取、整理、写回或成长；群聊不接入。图片/语音/表情包先核对可行性，不要求首版完成。

- `app/packages/qq_private_bridge` 是独立、无 Flutter/主数据库依赖的 Dart 子项目：HTTP/WebSocket 协议、只接 C2C 的事件边界、绑定、独立短期上下文、投递日志。
- `app/lib/integrations/qq_private` 是宿主适配器。`QqReadOnlyContext` 返回已有记忆和表达规则快照，通过独立SQLite只读连接及共享MemoryRetrievalPolicy纯判定检索；不触发主数据库onOpen/迁移/修复，不保留跨存档替换的数据库句柄；不改变回忆次数/冷却，不调用主 ChatController、MemoryExtractor、Dream 或 Agent。
- `app/lib/qq_private_main.dart` 只启动本入口，跟随当前正文提供商、模型/Key/endpoint/力度，不复制主 App 的主动调度。主 App 忙时新 QQ 生成等待；QQ 不占主聊天 lease，不提交主聊天记录。
- Android `qq/QqPrivateService.kt` 是独立 opt-in 前台服务，无悬浮权限/悬浮窗口/屏幕控制/语音播放要求；关闭悬浮球不应关闭 QQ。无开机自启，强制停止/系统限制或断网不能保证在线。
- 设置入口：更多→QQ 私聊·测试版。设备 secure storage 单独保存凭据与身份，不进入主 API 导出/存档。输入 AppID/Secret、启动后显示十分钟本地一次性绑定码，需在本人 QQ 私聊发送；不以首个来消息的人自动认主人。
- 其他私聊、群聊/频道及机器人消息在读取记忆前拒绝。重新绑定更换独立 namespace，旧 QQ 上下文不带给新身份。群聊记忆的隔离/归档/提取仍是后续任务，不以首版完成代替。

## 首版能力及限制

支持纯文字私聊；不是 dsh 的完整移植，不提供工具循环、多媒体、主动发往 QQ 或群聊。文字 QQ 历史最多使用十二轮，只用于本入口短期连续性，不进入主记忆/梦境/关系/作品。投递日志位于 App 私有 `qq_private_v1` 目录，凭据在 secure storage；该试验数据未接入主存档协议。绑定前及非主人请求不读取私人记忆。

按明确回执更新送达状态；只在已拒绝的 HTTP401 后刷新一次凭据。发送超时或进程退出导致投递不确定时不自动重发；生成中进程退出后不自动重复付费调用，需用户检查后另发消息。待处理队列最多20条；旧事件和超过四分钟的本入口任务保守过期，不擅自转主动。QQ 官方不同位置的被动有效期文档存在5/60分钟表述不一致，首版不依赖更长窗口。回复按 Unicode 字符拆段，最多四段，超长/截断/空回复不作完整成功。重连期间只恢复已接收的本地队列；跨进程平台离线消息的完整补发尚未承诺。

模型正文直接调用当前配置的最终提供商，工具未接；上游费用仍会发生，QQ 用量暂未合入主聊天每日账本。共享模型接口的限流仍可能相互影响。不开启本地 TTS，所以不会因 QQ 回复而抢手机音频或启动 Live2D。

## 多媒体核查（平台可行，不代表已实现）

- QQ 官方 C2C 事件定义图片及语音附件，语音可含 `voice_wav_url` 和 `asr_refer_text`；字段可能缺失，不能假定每条语音都有转写。用户语音输入还需要明确转写失败策略，不能把音频链接当作已经听懂。
- 腾讯 SDK 的音频模块明确将 WAV/MP3/SILK 作为默认直传格式；App 本地 Genie 已有生成 WAV 的独立 generate 接口。后续可以按本轮要求发送语音条或只发语音，无需把自动朗读改成每轮发送。须另行验证真实上传/播放，不能把文件附件当作原生语音条验收。
- 图片可以接现有识图接口；本地 PNG/JPEG/GIF 表情包可走图片媒体上传。QQ 商店表情、表情回应、GIF/WebP客户端表现不等于本地图发送，需分别实测。
- 本地语音合成与 App TTS 共享原生生成 token/引擎；文件生成虽不必播放，仍需独立任务所有权/排队/取消后再接入，避免停止 App 朗读误取消待发送音频。比文字额外消耗本地 CPU，不承诺零影响。

来源：

- 腾讯官方 [C2C事件](https://bot.q.qq.com/wiki/develop/api-v2/autogen/event/c2c_message_create.html)、[发送消息](https://bot.q.qq.com/wiki/develop/api-v2/autogen/api/v2_users_user_openid_messages.post.html)、[连接方式](https://bot.q.qq.com/wiki)。
- 腾讯 SDK commit `429a0f1b798f3b0fcef3679e207dbc0469a1df2d`：`src/protocol/gateway/gateway-connection.ts`、`api/token.ts`、`api/media.ts`、`utils/audio.ts`。
- 增强插件 commit `5f455e2a057210e2cdf650d2da5750a17224c438`；用于参考功能边界，不引入它的性格/好感/群管理系统。

## 验证与真机入口

自动回归目标：绑定/拒绝身份、群入口隔离、重复事件、慢生成期间接收后续消息、读写冻结、App优先、未知投递/进程恢复、Unicode拆段、真实本地HTTP/WebSocket协议、全库快照前后一致。既有完整测试和 Android15 原生/签名/载荷门继续执行。本地154门执行在第2项被稀疏工作区缺失的既有Cubism资源阻断，未更改校验或伪造通过；版本/总账校验与Python语法/diff检查通过，完整源码门由恢复固定资源的CI执行。

真机先检查：不用悬浮球启动连接→本人绑定→文字私聊→关联旧记忆→核对主聊天/记忆未写入→切 App/QQ及锁屏→断网重连→关闭连接。需要用户自己在设置中填入 QQ 凭据；不索取或提交凭据到仓库。真实腾讯权限/接口兼容、HyperOS保活、后台耗电和最终语气仍待真机，不因自动回归通过宣称已验收。

## 历史候选与修订（不覆盖顶部最终交付）

首候选远端6ee0e84（本地a00903bc，同treeca8194f4）：专项40180984983的Dart分析通过，1144通过/2失败。HTTP协议回归被Flutter测试环境默认HTTP400覆盖阻断，改为向QqApi注入真实loopback HttpClient，不跳过或伪造协议测试；全库只读断言真实发现listRuleLayers()会更新rule_layers.updated_at，QQ适配器改成直接只读SELECT，不改原有App的规则修复行为。保留全库逐表比较断言。另补绑定身份按namespace独立保存，迟到旧绑定不能覆盖新配置，关闭时等待入站/落盘，后台未运行状态及MIT许可证随包注册。修订候选继续完整验证；不以首候选分析通过替代最终测试/构建。

生产连接补充：QQ现在每次有限查询打开并关闭readOnly=true、singleInstance=false的SQLite连接，不调用AppDatabase的onOpen修复；避免只读查询之外的启动修复和存档替换后旧句柄。另补真实文件数据库只读打开/未迁移回归，并将QQ原生Service测试加入完整构建的Gradle过滤清单。

第二候选远端dc4d5b48（本地e2a94794，同tree5c64d1bc）：专项40181472640分析通过，1146通过/1失败；真实HTTP、只读全库对比和迟到绑定回归已通过。失败为慢回复期间接收第二条消息的异步完成边界：测试在第一条内存状态已sent但落盘/队列尚未结束时立即断言第二条。改为等待完整送达结果，工作器同时改为持续取队头，第一条完成后立刻处理新入队，不依赖三秒轮询。完整构建40181472653以该候选为历史，不作为后续修订的完成证据。第三候选含生产SQLite只读打开、真实文件回归与原生测试过滤补充，继续CI。

第三候选远端38682694（本地cf12e5e1，同treef9d03e2c）：专项40182230304/job121135503833通过Dart分析与1148项；分析有既有及新增非fatal提示，不记零告警。真实HTTP/WebSocket、文件只读打开、全库一致性、绑定竞态与队列回归通过。完整40182230272的Android15基础回归121135715770成功；build121137009785在第134/154源码门被另三处缩写版号白名单拦截，Kotlin/App全量/打包未执行。补充v04256/v04260/v04261的135+379允许值，三项本地检查通过；扫描21条能匹配前版的实际版本正则，新版均匹配。保留全部业务断言；UI把平台发送回执表述为“QQ已接收回复”，不当作用户端已读/实际听到。第四候选继续完整CI，未交付APK。
