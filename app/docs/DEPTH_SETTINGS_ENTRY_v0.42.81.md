# +325 · 立体背景新版设置入口修正

基线+324/e09a4cf；用户2026-10-07 20:08报告没有找到开关，承接既有修复/推送/构建授权。目标0.42.81+325，分支agent/v04281-depth-settings-entry。

## 已确认原因
chat_page.dart的_openQuickPanel在默认Material3主题先调用_openQuickPanelV2并return。+324只在return后的旧面板添加立体背景开关，新面板实际导航到ChatVisualSettingsPage，该页面未接入。此前测试覆盖渲染/传感器和备份，漏掉用户实际进入的设置页面；这是明确入口漏接，不归因于用户没找到或传感器缺失。

## 限定修正
给ChatVisualSettingsPage增加同一chat_background_depth和chat_background_depth_strength的读取、开关和20%—100%滑钮。沿用RoomDepthBackground.parseStrength，默认关闭、55%，保留角色聊天舞台显示条件。返回聊天时沿用现有_loadVisualSettings及原生参数同步。只为该页面增加可选数据库注入用于真实SQLite交互验证，正常运行仍使用AppDatabase.instance。

## 验证与边界
验证默认Material3的实际分类页面显示入口，点击后真实SQLite保存、滑钮保存、重新进入读取及舞台关闭/重开设置保留。不改传感器/背景shader/Live2D/备份恢复/桌宠/TTS/主动聊天。沿用完整CI和同签名未发布APK；CI通过不等于真机观感已通过。

## 状态
CI PASSED / APK READY / TRUE DEVICE PENDING。

本地验证：146/149源码门通过；桌宠源帧和LingChat特效由CI恢复，本地不存在，另缺kotlinc，3项待完整CI，不删门不改断言。总账、连接清理共享核心边界、workflow YAML/嵌入Python语法通过。新增chat_visual_depth_settings_test.dart实际点击默认Material3分类页面的开关和滑钮，真实SQLite保存，重建页面回读、舞台关闭/重开保留设置；后续已在专项和全量CI执行通过。

专项Actions 37619987582已成功，head 4df64d8c7a099de60fe8317ea10c6a7674b6152d，job 112787510566。407项行为回归通过，包括新增实际Material3页面SQLite保存/回读测试。Flutter analyze门通过（现有非致命info/warning仍存在，不声称零提示）。完整构建最终结果见下；此段记录专项先通过的验证顺序。

## 最终交付
2026-10-07 20:44：CI PASSED / APK READY / TRUE DEVICE PENDING。交付源码4df64d8c7a099de60fe8317ea10c6a7674b6152d，tree d1755c834e625dc294b15983aae992f6f417e994。完整Actions 37619987572与专项37619987582均成功：149项源码门、1407项全量Flutter、407项专项、20项Android35原生、Kotlin、签名与完整资源校验通过。build job 112789664873，native job 112787541978。本轮没有CI失败重试；本地缺资源/工具的3项最终均在CI通过。入口漏接及旧版测试覆盖不足已纠正；不把CI结果当真机观感验收。

下载页：https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-226ea340df609599817a
APK：AI-Companion-v0.42.81-325-Depth-Settings-Entry-APK.apk，736750241 bytes，release 405750901（draft=true），asset 618659910（uploaded）。SHA-256：a0bc657a79b194ff5b1423cd7a3c09341bcd4157f30cf3c587a8d51123c07309。签名证书SHA-256：30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48。raw CI monitor .ci/v04281-monitor.txt的run/head/signer/hash与上传资产digest一致。未合并main、未正式发布。

路径：聊天顶部头像/DeepSeek→聊天画面→聊天背景下方“立体背景”；需开启“角色聊天舞台”。实际手机入口使用、立体观感和耗电待用户确认。唯一当前总账已更新顶部快照及文末正式交付证据。
