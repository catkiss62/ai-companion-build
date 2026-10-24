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
