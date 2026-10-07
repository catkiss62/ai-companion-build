# +326 背景整体平移（Device Motion）

## 请求与参考证据
2026-10-07 22:21用户明确要求背景增加整体平移，参考已发Wallpaper Engine APK的Device Motion。已核对upload/base.apk，包名io.wallpaperengine.weclient，SHA-256 a6ca6d5ce34a1967fe987183076f7cf6f3b67a44fe720d69ffbb176173d543cc。assets/locale/ui_en-us.json中ui_browse_properties_parallax_gyro=Device Motion，中文为设备运动；Depth Parallax另列为深度视差。这足以确认模式区分，不等于已还原闭源原生方向/幅度参数，不能声称逐参数复刻。

## 实现方案与边界
普通立绘Flutter与原生Live2D背景同步改shader：统一平移量tilt * .035 * strength，叠加已有tilt * .018 * strength * (depth - .15)深度项。统一移动与原深度项同向，原深度幅度不变；沿用现有立体背景开关和20%—100%强度，默认55%。开启时每边预留.06 * strength纹理边距，总最大位移(.035 + .018*.85) * strength=.0503 * strength，小于预留边距。平移作用于同一底图/深度图的坐标基准，避免深度和颜色错位；迭代深度采样仍保留。沿用现有相对姿态、平滑和30Hz生命周期管理。人物、聊天框、按键保持原坐标；关闭仍为原静态背景，缺纹理/不支持时沿用原回退。

## 验证计划
真实ES2像素测试证明：深度中性时整张背景仍双轴移动；正负倾斜对称、强度递增；有深度时近景仍比远景移动更多；关闭不动，纹理不逐帧重载。Flutter用实际编译shader及合成图像核对同等方向、幅度和边缘。沿用149项源码门、全量Flutter、专项、Android原生、签名/完整资源校验。CI不等于真机手感通过。

## 状态
CI PASSED / APK READY / TRUE DEVICE PENDING。基线50eb9b6，分支agent/v04282-device-motion，目标0.42.82+326。

本地验证：146/149源码门通过，另外3项因缺桌宠帧、LingChat特效或kotlinc待CI；workflow YAML/嵌入Python语法、总账及共用恢复核心边界通过。新增Flutter实际shader像素测试2项、原生ES2像素测试1项，并升级旧近远景断言验证同时具备整体移动和深度差异；后续已在专项及完整CI执行通过，见下方最终交付。

## +326 背景Device Motion整体平移 · 最终CI与未发布APK交付

2026-10-07 22:53，0.42.82+326，agent/v04282-device-motion，源码b3258c94f2c8d379dd1a571d0021fcecb41a3d6f，tree efe13605076e3b56c37258b6b9ad4f5683c9c869。状态CI PASSED / APK READY / TRUE DEVICE PENDING。

用户2026-10-07 22:21要求加整体平移，对照之前发送的壁纸APK Device Motion模式。已验证本地upload/base.apk包名io.wallpaperengine.weclient，SHA-256 a6ca6d5ce34a1967fe987183076f7cf6f3b67a44fe720d69ffbb176173d543cc；英文/中文界面资源分别列Device Motion/设备运动和Depth Parallax/深度视差。此次实现的是明确要求的行为，未声称完整还原该APK闭源方向或幅度参数。

修改清单：Flutter房间shader与原生Live2D背景shader同步叠加统一tilt*.035*strength平移，已有深度位移系数.018与两次深度采样保留；移动后的同一坐标作为底图与深度图基准。每边预留.06*strength纹理边距，大于最大合成位移.0503*strength；关闭仍为静态背景。沿用现有开关、默认55%强度及20%—100%滑钮，更新新旧设置页说明；原姿态校准、平滑、前后台生命周期继续使用。人物、聊天UI不参与平移。没有改聊天/人设/主动/TTS/恢复核心。

验证：完整Actions 37637286301（build job 112849532063，native job 112846755894）与专项37637286323（job 112846707563）均成功，head与交付源码一致。149项源码门、1409项全量Flutter、409项专项、21项Android35原生，Kotlin、签名和完整资源校验通过。新增2项Flutter实际编译shader像素测试和1项原生ES2像素测试，证明深度中性区域仍整体移动、双轴正负方向、强度递增、近景移动更多、边缘覆盖、关闭静态；原近远景原生断言升级为远景也移动且近景更大。此轮无CI失败重试，未删检查或削弱断言。Flutter analyze门通过，现有非致命info/warning仍在，不声称零提示。本地缺资源/kotlinc的3项门最终在完整CI全部通过。

下载页：https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-1ab7a7e7f56954bd0c48
文件：AI-Companion-v0.42.82-326-Device-Motion-APK.apk；736750349 bytes；release 405875340（draft=true）；asset 618992206（uploaded）。
APK SHA-256：f16d4c951b90407a89f89d0ca98f3ccf7b25bbd7ed31618b232ab00c1c884b29
签名证书SHA-256：30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48
CI monitor：https://raw.githubusercontent.com/catkiss62/ai-companion-build/ci-monitor-v0345/.ci/v04282-monitor.txt，status=success、run/head/signer/hash与上传APK digest逐项匹配。
Actions API时间：开始2026-10-07T14:30:36Z、完成记录更新2026-10-07T14:50:24Z（UTC）。本轮已完成，不能把旧工具状态当作仍在构建。未合并main、未正式发布。

入口仍是聊天顶部头像/DeepSeek→聊天画面→聊天背景下方“立体背景”，需开启角色聊天舞台。已有开启设置保留，升级后同时叠加整体移动与深度效果。+325深度观感用户已认可，+326实际整体移动手感、画面裁切、耗电与长期效果待用户真机确认，不能把CI像素通过当真机通过。

交付文档收尾：本地总账校验曾触发顶部快速索引100KB限额；收短+325重复摘要后复验，正式记录和冻结归档保留，未修改上限或跳过检查。APK与CI结果不受影响。
