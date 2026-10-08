# v0.42.87+331 Live2D耳鳍与表情分层

## 授权与范围

2026-10-08 16:22用户授权实施。仅修改Live2D表现；道具动作仍按明确语境选择，无表情频率配额。保留+330其他功能。

## 表情

七个预设作为独立face题，wink系列作为独立wink题，与emotion、四拍五官、action在同一次Jev请求中判断。明确允许叠加，不要求必选。桥接增加独立wink字段，旧三参数方法保留。原生七预设同层互斥、wink同层互斥、两层可共存；比耶wink与占手动作的互斥不变。预设仍约4.5秒后释放，不变为常驻表情。按参数执行顺序叠加，不承诺相同五官参数完全独立。现有本地诊断保留判断概率与提交的完整计划，新增字段随计划记录。

## 耳鳍

上游菜菜fb04512f与AI的初始配置相同。发现固定pair旋转5度、右耳14度、左耳-9度在clip坐标直接旋转，非正方形舞台下非像素等距。更长的聊天舞台会改变初始几何，即使人物未越界、整体缩小仍存在。修正两级耳旋转矩阵的交叉项，以逻辑sceneHeight计算，保留原校准平移及旋转支点。整体模型、呆毛、尾巴参数及物理不变。

这是已确认的数学隐患修正；截图实际差异的唯一根因尚未经真实模型A/B验证。原版校准本身也带有该失真，因此不宣称与旧菜菜截图逐像素一致。真机检查两耳、缩小、转头、输入法打开关闭；不以盲目右耳拉宽掩盖问题。

## 验证

新增几何测试覆盖两侧与pair角度、横竖舞台、缩放、支点和校准平移守恒；原生互斥测试覆盖七预设与wink共存/同层互斥/手势冲突。Flutter测试覆盖分题同请求和四类字段同时传递。源代码pin仅更新已审阅的预设互斥修改，其余原版代码继续完整校验，耳旋转hook及独立helper由行为测试验证。

状态：CI PASSED / APK READY / TRUE DEVICE PENDING。

## +331 最终CI与未发布APK交付

源码a857385dec246e69a71510901511c84ba7a7b75d，tree aa1ccadb8e4c5f7baddfdb12728e30d95612e456。完整Actions37750314371与专项37750314477均成功：149源码校验、448专项、1447全量Flutter、29 Android原生回归及Java/Kotlin单元测试通过。耳旋转像素长度/支点/缩放测试与预设/wink互斥测试包含在Caicai*Test门内。签名/APK资源校验通过，沿用+330签名。

下载：https://github.com/catkiss62/ai-companion-build/releases/download/untagged-3284acba17a4e6bbaa4b/AI-Companion-v0.42.87-331-Live2D-Ear-Face-APK.apk
草稿页：https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-3284acba17a4e6bbaa4b
Release406622978，asset621281205，736801493 bytes。
APK SHA256：ff5d1963c0e779ac033b1f05cf638e7d93f43e489116f718b7daa6db3debae87。
Signer SHA256：30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48。

状态CI PASSED / APK READY / TRUE DEVICE PENDING。用户需观察画面右耳默认宽度、变小及转头、输入法开关，并自然观察七预设与wink组合。数学失真已修正，不等同已证实截图唯一根因；没有真人模型渲染A/B验收。表情不设频率配额，道具策略不加强。未合并main、未公开发布草稿、未上传私有模型和用户诊断。
