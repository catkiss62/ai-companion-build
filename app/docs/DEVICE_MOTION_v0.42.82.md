# +326 背景整体平移（Device Motion）

## 请求与参考证据
2026-10-07 22:21用户明确要求背景增加整体平移，参考已发Wallpaper Engine APK的Device Motion。已核对upload/base.apk，包名io.wallpaperengine.weclient，SHA-256 a6ca6d5ce34a1967fe987183076f7cf6f3b67a44fe720d69ffbb176173d543cc。assets/locale/ui_en-us.json中ui_browse_properties_parallax_gyro=Device Motion，中文为设备运动；Depth Parallax另列为深度视差。这足以确认模式区分，不等于已还原闭源原生方向/幅度参数，不能声称逐参数复刻。

## 实现方案与边界
普通立绘Flutter与原生Live2D背景同步改shader：统一平移量tilt * .035 * strength，叠加已有tilt * .018 * strength * (depth - .15)深度项。统一移动与原深度项同向，原深度幅度不变；沿用现有立体背景开关和20%—100%强度，默认55%。开启时每边预留.06 * strength纹理边距，总最大位移(.035 + .018*.85) * strength=.0503 * strength，小于预留边距。平移作用于同一底图/深度图的坐标基准，避免深度和颜色错位；迭代深度采样仍保留。沿用现有相对姿态、平滑和30Hz生命周期管理。人物、聊天框、按键保持原坐标；关闭仍为原静态背景，缺纹理/不支持时沿用原回退。

## 验证计划
真实ES2像素测试证明：深度中性时整张背景仍双轴移动；正负倾斜对称、强度递增；有深度时近景仍比远景移动更多；关闭不动，纹理不逐帧重载。Flutter用实际编译shader及合成图像核对同等方向、幅度和边缘。沿用149项源码门、全量Flutter、专项、Android原生、签名/完整资源校验。CI不等于真机手感通过。

## 状态
IMPLEMENTED / CI PENDING / APK PENDING / TRUE DEVICE PENDING。基线50eb9b6，分支agent/v04282-device-motion，目标0.42.82+326。

本地验证：146/149源码门通过，另外3项因缺桌宠帧、LingChat特效或kotlinc待CI；workflow YAML/嵌入Python语法、总账及共用恢复核心边界通过。新增Flutter实际shader像素测试2项、原生ES2像素测试1项，并升级旧近远景断言验证同时具备整体移动和深度差异；尚待CI执行，未声称通过。
