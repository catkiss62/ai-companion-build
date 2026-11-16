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
