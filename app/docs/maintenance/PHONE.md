# 模拟手机、日历与日常内容

核对基线：2026-11-17 / +439。状态为源码入口核对，不等同真机通过。[目录](INDEX.md) · [更新规则](CHANGE_GUIDE.md)

## 入口与职责

| 入口 | 用途 |
| --- | --- |
| [simulated_phone_repository.dart](../../lib/core/phone/simulated_phone_repository.dart) | 只读快照与内容访问 |
| [simulated_phone_page.dart](../../lib/features/phone/simulated_phone_page.dart) | 模拟手机界面 |
| [calendar_reminder_store.dart](../../lib/core/phone/calendar_reminder_store.dart) | 提醒持久状态 |
| [calendar_reminder_page.dart](../../lib/features/phone/calendar_reminder_page.dart) | 提醒界面 |
| [fate_wheel_catalog.dart](../../lib/core/fate_wheel/fate_wheel_catalog.dart) | 命运之轮内容 |
| [companion_home_state.dart](../../lib/features/home/companion_home_state.dart) | 她页面状态 |

## 状态与边界

读取手机快照不应自动制造新的感知/想法。日记、随笔、相册、愿望与提醒有不同生成/已读/时间边界；展示红点不是内容生成成功的证据。日历时间取实际设备上下文。

## 小改动如何落点

改展示先查读模型；改生成频率查失败重试与跨日记录，不能用 UI 每次进入触发生成。提醒小窗同时检查后台通知、消除及恢复。

## 回归入口

- [phone_history_v042105_test.dart](../../test/phone_history_v042105_test.dart)
- [calendar_reminder_delivery_test.dart](../../test/calendar_reminder_delivery_test.dart)
- [diary_retry_repository_v04269_test.dart](../../test/diary_retry_repository_v04269_test.dart)

上述为定位起点，不代表覆盖全部调用者。历史教训及证据见 [回归索引](REGRESSIONS.md)；执行方式见 [验证导航](VERIFICATION.md)。

人工/真机重点：跨日、提醒点击/取消、读后红点及内容生成失败后的恢复。

## +443 日历和完整历史

[phone_history_store.dart](../../lib/core/phone/phone_history_store.dart)把旧日记/随笔事务迁入逐条settings记录及owner索引，迁移可重复，失败整笔回滚、不标完成。旧JSON仅为最近180/300条兼容投影；新生成正文与完整历史行使用同一工作fence提交，完整历史不按条数删除。日历按local_day索引范围读取，每页50条，随笔首页50条。历史已被旧版本裁掉的内容不会凭空恢复。

历史和迁移标记随现有settings备份/恢复，无新schema或独立历史存档；日记媒体引用不因近期窗口淘汰而清理，生成任务确认来源时兼容历史owner索引。查手机的日记入口恢复 +442 的日记列表。日记和随笔右上角均可打开日历，独立日历继续按日期分页读取完整历史和日记配图。phone.search/read仍使用既有近期只读投影，未扩展Agent历史搜索范围。购物车生产开关常量关闭、UI移除，原代码和数据保留，显式读取旧购物车仍可用。

验证：[phone_history_retention_test.dart](../../test/phone_history_retention_test.dart)覆盖迁移重复/失败回滚、日期分页、旧缓存替换后历史存留、数据库备份回读和工作guard拒绝；日记重试测试验证修复正文同步归档且购物车生成器零调用。真机验旧存档升级、日期切换、日记配图、列表排序及导出/导入。

+456：日历 WAIT 结束该次文字提醒；临时失败按 occurrence 持久记录次数，首次失败后一分钟、再次失败后五分钟再试，最多三次。不改变响铃和确认。
