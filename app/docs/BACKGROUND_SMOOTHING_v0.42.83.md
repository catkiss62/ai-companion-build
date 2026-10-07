# +327 背景姿态与逐帧平滑

## 问题与边界
2026-10-07 23:53用户报告背景帧数低，23:55确认人物动画正常。代码证据：姿态请求33333微秒、30ms事件门槛，Flutter/native直接使用事件坐标。修复明确存在的30Hz台阶，不把人物正常当作排除背景GPU耗时的证据。基线67186ea，分支agent/v04283-background-smoothing，目标0.42.83+327。

## 设计
请求姿态60Hz（16667微秒），15ms重复事件门槛避免16ms附近抖动导致误降频；硬件实际频率仍由设备决定。原姿态滤波120ms保留。显示位置另按35ms时间常数向最新目标指数平滑，不做未来姿态预测：Flutter ticker跟显示帧，只有有未收敛目标时运行；native在既有GL帧更新，无额外渲染循环。停用/后台/切页/校准通过reset立即归零；切换深度开关和GL上下文重建也重置native显示姿态。静止收敛阈值0.0001，Flutter自动停ticker，避免静态持续重绘。不调整人物帧率、shader采样次数、整体/深度幅度和边缘预留。

## 验证
真实Flutter widget在单次姿态输入后多个显示帧持续重绘，收敛后不再调度，后台/切页停止；平滑核心验证时间一致、无越界、逆向、非法输入和reset。原生通过实际ES2像素与注入单调帧钟证明无新事件的连续帧仍变化；旧几何像素测试在目标收敛后保留原断言。原帧校准/开关生命周期、像素边缘和设置保存回归继续跑。目标为移除已知30Hz限制及插帧台阶，CI不证明用户设备实际FPS或功耗。

## 状态
CI PASSED / APK READY / TRUE DEVICE PENDING。本地149源码门中146通过，3项缺恢复资源或kotlinc交CI补验；新增host平滑器加入既有host排除清单，导入源码原26文件及SHA不变且重验通过。工作流/YAML及内嵌Python语法、差异空白、总账快速索引和冻结归档校验通过。Flutter/Android与完整CI已执行成功，同签名未发布APK已完成，证据如下。

## +327 背景逐帧平滑 · 最终CI与未发布APK交付

2026-10-08 00:37（北京时间），0.42.83+327，agent/v04283-background-smoothing，源码6dbde7c49a96f732a8f35975b2461ec27ac1e077，tree 4a4f89a14e35cf41590677a72ca355c0bdb69cce。状态CI PASSED / APK READY / TRUE DEVICE PENDING。

问题证据：用户2026-10-07 23:53报告背景帧数偏低，23:55确认人物动画正常。代码中的姿态请求33333微秒和30ms门槛将目标更新限制在约30Hz，Flutter/native背景直接使用事件位置。这是可确认的台阶来源；人物正常不能单独排除背景GPU成本，尚无用户设备实测FPS。

修改清单：姿态改为请求16667微秒、15ms重复事件门槛，实际采样由硬件决定；既有120ms姿态滤波保留。Flutter背景由显示帧ticker按35ms时间常数向最新目标平滑，原生在既有GL帧做相同时间响应，无新原生渲染循环。收敛后Flutter停止ticker；关闭、切页、后台、传感器不可用及重新校准立即停止/归零，native深度开关及GL重建也复位。原整体平移、深度shader、强度和边距均未改，人物动画帧率未改。

验证：完整Actions 37650541415（build job 112895018928、native job 112892450243）及专项37650541791（job 112892410889）均success，head与交付源码一致。149项源码门、1413项全量Flutter、413项专项、22项Android35原生通过，Kotlin/Java单测、analyze、签名及完整资源门通过。新增Flutter核心3项、真实widget1项，Java平滑核心3项、ES2像素1项：低频单次输入之间连续变化、30/60/120帧时间响应一致、收敛停调度、后台/切页/释放/复位停止。原像素几何测试等目标收敛后仍执行原幅度/边缘断言；未削弱断言或跳过检查。本轮CI无失败重试。新增host-owned RoomMotionInterpolator加入既有host排除清单，导入源码26文件数及原SHA保持，原源码钉住门通过。本地缺桌宠帧/LingChat特效/kotlinc的3项已在CI补验。analyze仍有非致命提示，不声称零提示。

下载：https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-f30a80b0b9613d403ee3
APK直链：https://github.com/catkiss62/ai-companion-build/releases/download/untagged-f30a80b0b9613d403ee3/AI-Companion-v0.42.83-327-Background-Smoothing-APK.apk
文件：AI-Companion-v0.42.83-327-Background-Smoothing-APK.apk；736752169 bytes；release 405962303（draft=true）；asset 619217660（uploaded）。
APK SHA-256：b122abdb3a884a90b2cca75ff62d1eab1be6067358d8ae22feddd3d4934cd4eb
签名证书SHA-256：30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48
CI monitor：https://raw.githubusercontent.com/catkiss62/ai-companion-build/ci-monitor-v0345/.ci/v04283-monitor.txt，status/run/head/signer/hash与release APK digest逐项一致。原62文件LingChat、四张背景/深度图、编译shader、131项星谷、塔罗22张、Genie/桌宠资源均校验通过。
Actions API：2026-10-07T16:15:01Z开始，2026-10-07T16:34:48Z更新为completed/success。当前已结束，不应将旧工具状态判为还在构建。没有合并main或正式发布。

用户设备的实际FPS、手感和功耗仍TRUE DEVICE PENDING；此次交付证明去除了已知30Hz姿态限制并有逐帧过渡，不能保证任何手机稳定60FPS。沿用聊天顶部头像/DeepSeek→聊天画面→聊天背景下“立体背景”及既有开关/强度，无需重新开通。构建和最终总账分别提交，APK对应上述源码commit。
