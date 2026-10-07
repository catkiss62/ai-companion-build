# +325 · 立体背景新版设置入口修正

基线+324/e09a4cf；用户2026-10-07 20:08报告没有找到开关，承接既有修复/推送/构建授权。目标0.42.81+325，分支agent/v04281-depth-settings-entry。

## 已确认原因
chat_page.dart的_openQuickPanel在默认Material3主题先调用_openQuickPanelV2并return。+324只在return后的旧面板添加立体背景开关，新面板实际导航到ChatVisualSettingsPage，该页面未接入。此前测试覆盖渲染/传感器和备份，漏掉用户实际进入的设置页面；这是明确入口漏接，不归因于用户没找到或传感器缺失。

## 限定修正
给ChatVisualSettingsPage增加同一chat_background_depth和chat_background_depth_strength的读取、开关和20%—100%滑钮。沿用RoomDepthBackground.parseStrength，默认关闭、55%，保留角色聊天舞台显示条件。返回聊天时沿用现有_loadVisualSettings及原生参数同步。只为该页面增加可选数据库注入用于真实SQLite交互验证，正常运行仍使用AppDatabase.instance。

## 验证与边界
验证默认Material3的实际分类页面显示入口，点击后真实SQLite保存、滑钮保存、重新进入读取及舞台关闭/重开设置保留。不改传感器/背景shader/Live2D/备份恢复/桌宠/TTS/主动聊天。沿用完整CI和同签名未发布APK；CI通过不等于真机观感已通过。

## 状态
IMPLEMENTED / CI PENDING / APK PENDING / TRUE DEVICE PENDING。

本地验证：146/149源码门通过；桌宠源帧和LingChat特效由CI恢复，本地不存在，另缺kotlinc，3项待完整CI，不删门不改断言。总账、连接清理共享核心边界、workflow YAML/嵌入Python语法通过。新增chat_visual_depth_settings_test.dart实际点击默认Material3分类页面的开关和滑钮，真实SQLite保存，重建页面回读、舞台关闭/重开保留设置；尚未执行Flutter测试，待CI。
