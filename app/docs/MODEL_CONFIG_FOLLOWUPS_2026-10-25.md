# 第一通道思考力度、作品凭据及插件化讨论

日期：2026-10-25（Asia/Shanghai）。基线v0.42.133+377，运行源码e3a400c5；后续九类审查文档a55e5cfd（本地293f120b同tree 1a2c0d99a53fb4b236404ed6536f10455b589edb）。本轮用户要求先记录两项设置细节并核查，插件框架仅询问可行性。本文件为事实与待办记录，不代表功能已经修改。

## M1 · 第一通道DeepSeek缺少独立思考力度入口

现状证据：

- settings_category_pages.dart:207、271、805只有一套_effort / reasoning_effort，界面选项与保存值都按最终回复_chatProvider归一化。
- chat_api_provider.dart:51双通道把max归一化为high；第一通道没有单独保存的力度值，不能在选择第二通道时独立设置第一通道max。
- chat_controller.dart:1290创建generation job，保存当前effort；durable_generation_runner.dart:909将job.reasoningEffort传入请求。generateInternal:1115和最终生成共用generate。因此不是DeepSeek完全没有发送力度参数，而是第一/第二通道缺少独立配置和快照语义。
- 作品已有独立creative_work_effort。深度思考开关是Agent路由/预算开关，与模型reasoning_effort分别管理。

纳入九项修补同轮的待办：给聊天第一通道和最终回复分别提供、保存并使用各自力度，按接口支持的档位发送；核对普通生成、Agent规划、重试/恢复和手动DeepSeek接续，不能只增加界面下拉框。旧设置迁移保留实际行为，已登记任务保持对应参数归属。固定用途判断当前使用专用力度的，不因新增聊天设置自动全局改动。作品已有独立工作力度保持独立。

## M2 · 作品制作确实共用第一通道Key与地址

现状证据：

- settings_category_pages.dart:833明确写“复用上面的DeepSeek Key和地址”，保存工作设置时只有creative_work_model/creative_work_effort。
- creative_worker.dart:133、157调用SecureConfig.instance.readApiKey/readEndpoint；secure_config.dart:149、179将它们指向第一通道DeepSeek凭据。
- 制作Worker拥有自己的DeepSeekClient、creative_worker_lease_until、heartbeat和work/request身份（creative_worker.dart:26、48、59、146）。聊天拥有自己的client/chat_turn_lease。不存在仅因共用Key就必然串上下文或互相取消的结论。
- 自主作品使用CreativeAutonomyFence及空闲检查，聊天开始后可拒绝迟到提交；用户明确委托制作可以在普通聊天期间独立继续。这是现有产品行为，不应因拆Key而悄悄改成普通聊天取消全部已接受作品。
- 完成通知使用聊天通道并等待空闲（creative_delivery.dart:65、149）；作品内AI选择/陪玩与自主构思分别在creative_play.dart:225、creative_inspiration_engine.dart:36使用第一通道。不能把“制作凭据独立”误写成“所有带creative前缀的请求都必须换成工作Key”。

建议纳入同轮的配置方向：作品制作支持“跟随第一通道 / 独立配置”，独立时Key与endpoint成对使用，搭配已有工作模型和力度；升级默认保持旧跟随行为。凭据仍放安全存储，不进入普通存档、明文日志或公共仓库。设置、测试连接、实际请求及重启恢复须使用同一配置身份，不能把一个通道的Key发送到另一个通道的地址。

独立Key有利于配置、用量归属及撤销轮换，不能保证独立并发配额。DeepSeek官方当前按账号计算并发，不区分同账号不同Key；中转规则需要以实际提供商为准。客户端隔离、上游并发/余额、手机CPU/内存是不同问题。没有调用真实付费API或复现当前上游冲突，不能声称制作作品一定妨碍聊天，也不能承诺换Key就完全解决竞争。

关联核对：dream_engine.dart:140通过FirstChannelModel.work选用作品模型，但请求Key/地址仍从第一通道读取（同文件:30、39）。若工作模型以后允许来自不同独立接口，梦境“使用作品模型”的路由须连同提供商/凭据策略核对，避免只继承模型名而误配接口。作品内聊天、灵感判断、完成通知和梦境各自的通道归属要明确，不能一刀切替换。

历史检索未取得足以证明当初明确约定独立Key的原话；不以检索缺失否定用户记忆。本轮可确认的是当前实现没有作品独立Key入口。

## 插件框架/热更新：仅讨论，不纳入本轮改造

技术上可以设计宿主+脚本/HTML插件或接入Flutter补丁运行时。规则、配置、外置资源、已有宿主能力内的脚本可动态更新；标准Flutter release的Dart已AOT编译进APK，修改源码不会自动改变已安装版本。专用OTA方案可更新部分Dart逻辑，但补丁仍需构建测试，原生Kotlin/Manifest/平台桥/引擎更新仍要新安装包。

就本项目判断，全量插件化涉及宿主API、权限、任务调度、数据所有权、备份迁移、版本兼容、验证与回滚，属于架构迁移；不能把现有并发与恢复缺口转成插件后就认为消失。后续如有需求，可先评估资源包/规则外置和稳定功能接口，避免把这次九项修补变成全项目重写。本轮不采用OTA服务、不重构宿主、不构建新APK。

核查的官方资料：

- Flutter运行方式：https://docs.flutter.dev/resources/faq
- Android动态代码加载：https://developer.android.com/privacy-and-security/risks/dynamic-code-loading
- Flutter补丁方案的原生边界与构建：https://docs.shorebird.dev/code-push/patch/
- DeepSeek账号并发与Key：https://api-docs.deepseek.com/quick_start/rate_limit/

## 后续顺序

前轮建议保留G1–G6并增加G7“Agent、游戏厅及前后台执行衔接”，G7与G2/G3/G5验证共享机制。先处理九项及本轮两项设置待办、补真实入口回归，再固定代码做七类全局复查，最后统一全量验证/测试APK。此为后续安排，不将讨论、记录、实现、CI和真机结果混记。

## 用户补充：力度默认值与梦境选模型的目的

再次核对源码的事实：第一通道读取reasoning_effort，数据库初始化默认high，ReasoningEffort.fromApiName缺省也回落high；它不读取creative_work_effort。作品新委托从creative_work_effort保存自身力度，缺省max（creative_store.dart:232、244）。梦境从FirstChannelModel.work选择作品模型，未设时回落第一通道模型；dream_engine.dart:42明确固定high，不继承作品max。当前第一通道实际请求仍可能受用户保存的共用思考设置影响，不能把源码默认值当作已读取用户手机现值。

用户澄清：梦境优先作品模型，是希望以后作品模型改用更强模型时，梦境同步受益；并非明确要求梦境跟随作品max。历史可检索记录也支持“梦境跟随作品模型”，未取得力度联动约定。当前模型选择符合这一目的，先前提醒的是未来独立接口时模型与凭据同源的配套问题，不把现状误记为梦境选错模型。后续作品独立配置需确保梦境能访问所选作品模型对应接口；不因此擅自将梦境力度改max或新增梦境设置项。

## 用户补充：插件化的主要目标是自我迭代

用户强调主要动机是让伴侣能及时修改自己的上层功能与逻辑，缩短“发现小问题→修改→可使用”的周期，而不仅是减少安装包下载；已在手机使用插件式DSh，但没有指定具体安卓分支。不将桌宠动画来源仓库或某个DSh安卓宿主擅自认作用户安装的版本。

以DSH-APP/DSHA和WSK-build/DSHBox两个公开实现为例，安卓宿主预先提供WebView/原生桥及可运行Node等代码的环境，再通过插件层更新一部分功能。这证明宿主+可更新运行层在安卓可行，不意味着这些项目不再需要更新原生APK，也不据仓库宣传推断用户设备上的性能。

基于这个目标，建议由“暂不全量重构”细化为“自我迭代值得单独评估局部插件层”：稳定宿主管数据所有权、发送/取消、权限及安卓原生能力；可替换层先承载互动小功能、内容整理/选择、表达或展示策略等上层逻辑。先以一项可隔离、有版本和回退的模块验证AI修改→自动验证→试用→回退的完整过程。现有HTML小作品制作/预览管线可作为部分基础，不能直接当作已有通用自修改能力。

插件化、热更新能力与自我修改的执行权限分别设计。插件只使用宿主公开接口，新增原生接口仍通过宿主更新；不要让插件直接改正式库或撤掉未知写/取消/来源保护。具体运行时、首个模块、自动生效范围和验收标准留在未来独立设计阶段，本轮不安装DSh/OTA运行时、不替换Flutter/原生架构，不挤入九项及模型设置修补。

核查的示例实现：https://github.com/DSH-APP/DSHA ，https://github.com/WSK-build/DSHBox 。本节仍为讨论与事实记录，未改应用、未运行新测试或付费API。

## 用户补充：独立模型入口与 Flash＋High 的适用性

用户明确第一聊天通道也需要模型选择，力度默认 High；工作模型力度默认 Max，但可以调整。当前设置页已有“DeepSeek 内部模型”选择和可调整的工作模型/力度；待办是把第一通道模型与力度作为明确独立配置，并与最终通道及工作配置区分，覆盖保存、实际调用和任务恢复。不能将“补清楚独立模型入口”写成现有代码完全不能选模型，也不能将本次要求写成已实现。

梦境现有固定 High 是工程取舍，未取得本项目针对模型及力度的对照结果，不能追认为已证明“高端模型 High 一定足够”。核查 DeepSeek 当前官方 API 文档，`deepseek-flash` 对应 DeepSeek-V4.1-Flash-1017，支持 JSON 和工具调用，High 为思考默认档。基础 V4.1-Flash 模型卡明确主要 instruct 榜单采用最高力度 100；1017 模型卡报告通用推理/Agent 改进，也没有本项目梦境在 High/Max 下的对照。不能直接把榜单成绩当作 Flash＋High 的梦境质量。

结合现有任务，建议将 Flash＋High 作为梦境的默认候选：材料由宿主筛选，输出受到来源证据、最多 10 条 insights / 4 条 changes 和写回核验约束。但梦境还包含反证、角色归属和自我理解修订，结构合法不代表语义正确。最终是否足够，需用真实代表性材料比较来源引用、矛盾处理、用户/自身区分、不足证据时保留不确定及允许无变更；没有运行付费 API 或声称完成该比较。

如果采用该方向，可以让梦境独立默认 Flash＋High，并保留按需选择工作模型的余地，避免未来作品升级模型时梦境无条件跟随更高成本。此为针对用户新问题的建议，尚未将当前“优先工作模型＋固定 High”改为独立配置，也未额外承诺自动升级/自动重试模型。凭据与 endpoint 仍需跟随实际所选路由。

本轮官方来源：

- https://api-docs.deepseek.com/quick_start/pricing/
- https://api-docs.deepseek.com/guides/thinking_mode/
- https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash
- https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash-1017

## 用户补充：DSHA 找不到梦境与其他 AI 接手

GitHub 仓库元数据确认默认分支 `main`；2026-10-25 读取 `main/app/lib/core/self/dream_engine.dart` 返回 404，相同文件在开发分支提交 `4b7fcdaddf7f678388648a67a474e2b4aa600a9c` 存在。用户实际让 DSHA 读取的分支和工具日志尚未知，因此仅能给出条件解释：如果它读取默认 main，确实没有看到当前梦境入口，不能据此证明项目超出它的理解或修改能力。当前工作持续在用户授权开发分支，未擅自合并 main。

本会话能定位梦境，来自已有讨论背景、当前总账、正确开发分支和源码搜索/调用追踪的共同作用。其他 AI 可以使用同样资料接手；总览与源码入口应保存在仓库中，避免依赖某个聊天产品的上下文。已新增根目录 `AI_START_HERE.md`，并从两处 README 直接链接，记录分支、双语功能地图、梦境四个主文件、调用位置和三组测试；同时更正 README 仍称根目录 v2 为唯一当前总账的旧描述，根目录总账本身保持只读。

插件化可能让一个独立模块更容易定位、替换和即时试用，但必须先划清材料输入、结构化结果和宿主接口。对梦境可考虑先外置指令/整理策略，宿主继续持有调度、运行身份、来源核验及事务提交；整套梦境搬成插件并不会自动消除理解、并发或恢复问题。当前代码已按 engine/contract/material/store 分工，可以先通过交接入口解决发现困难，插件运行层留待未来独立设计。本轮只有文档变更，没有修改运行代码或新构建。

## 用户补充：开发环境与真机崩溃定位能力

用户转述 DSHA 当前自检为本机 ARM64、不能安装所需安卓工具链，验证依赖 Actions，不能直接运行目标 App。没有读取其实际工具日志，不能把这段自述当作所有 DSHA/ARM64 环境的固定能力边界。Android Studio 官方安装文档当前确实不支持 Linux ARM CPU；这也不能推广成所有 ARM 平台、所有替代工具链或远程验证方案都不可用。

补查 DSHA 当前源码 README，明确提供无线 ADB 配对、无障碍读屏/点按，以及截屏 OCR 等设备能力入口。若用户实际版本具备并已连通这些能力，可用于目标 App 操作及设备取证；这与本机能否编译 Flutter/Android 是不同能力。尚未核实用户安装版本、授权及连接状态，不能将公开功能表当作用户已经可以使用，也不能把 DSHA 本轮自述当作永久无法协助真机排查的证明。

本会话实际环境核查：x86_64；PATH 有 java，但无 flutter、dart、javac、adb、sdkmanager、gradle、emulator；ANDROID_HOME、ANDROID_SDK_ROOT、FLUTTER_ROOT 均未配置或不存在。因此不能声称本会话已拥有完整本地安卓工具链或可直接复现用户手机行为。当前已有完整 Flutter/Android 验证来自先前记录的 Actions；本轮只检查文档及运行文件未变化，没有运行新 CI 或真机测试。x86_64 有标准工具链适配条件，不等于已安装、已运行或具备用户设备访问。

延续由当前开发者处理的实际优势是项目上下文、调用链定位及已有修复/回归记录；工具链本身不构成准确修复偶发退出的保证。后续仍需把崩溃堆栈/进程退出原因与已有发送、接受、生成阶段诊断对齐，区分逻辑检查、CI 通过和真机问题已复现/解决。

## 用户补充：专用陪伴 App 与 DSHA 的适用性

DSHA 本身也是 Android App，区别是本项目专用陪伴产品与通用可扩展 Agent 宿主。就长期聊天、记忆/梦境、主动互动、悬浮窗、语音及游戏衔接的需求，建议保留专用 App 作为使用入口；统一数据与生命周期、定制交互和恢复路径，是可以针对目标优化的工程优势，不能写成当前实现天然更稳定。DSHA/插件适合快速试验可替换逻辑及通用工具任务，也可以扩展陪伴能力，但仍需实现这些产品机制。

同一模型、思考档位和上下文下，专用 App 不保证模型更快出字；界面响应、启动、内存、电量及后台可靠性取决于实现和设备，尚未做本项目与 DSHA 的对照。两者均受 Android 后台限制，专用 App 不代表永久常驻。建议未来采用专用宿主＋局部可更新逻辑层，兼顾陪伴体验与自我迭代；仍未启动架构迁移。

补充官方/源码资料：https://developer.android.com/studio/install ，https://developer.android.com/develop/background-work/background-tasks/bg-work-restrictions ，https://github.com/DSH-APP/DSHA 。
