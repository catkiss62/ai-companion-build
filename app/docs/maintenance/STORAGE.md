# 数据库、备份与后台恢复

核对基线：2026-11-17 / +439。状态为源码入口核对，不等同真机通过。[目录](INDEX.md) · [更新规则](CHANGE_GUIDE.md)

## 入口与职责

| 入口 | 用途 |
| --- | --- |
| [app_database.dart](../../lib/core/database/app_database.dart) | schema/事务与共享状态 |
| [brain_work_fence.dart](../../lib/core/database/brain_work_fence.dart) | 事务内身份和租约检查 |
| [shared_media_lock.dart](../../lib/core/storage/shared_media_lock.dart) | 跨进程媒体互斥 |
| [snapshot_restore_coordinator.dart](../../lib/core/sync/snapshot_restore_coordinator.dart) | 日志/提交标记/目录交换恢复 |
| [recovery_orchestrator.dart](../../lib/core/maintenance/recovery_orchestrator.dart) | 恢复调度 |
| [background_main.dart](../../lib/background_main.dart) | 后台 worker 与命令服务 |

## 状态与边界

当前 schema67；当前身份校验已改为读取真实声明，历史 schema62 注释不再参与该项判断。写入必须在实际事务内检查主脑身份/冻结与租约。媒体长复制不能只因 TTL 过期就抢锁。恢复采用日志及数据库标记，不能任意删中间目录。

## 小改动如何落点

这类改动不是安全的纯文案小修。先画出提交前/后与进程退出点，验证幂等、锁等待、存档引用与空间限制。恢复轮询和心跳各自时钟不能随意合并。

## 回归入口

- [brain_work_fence_test.dart](../../test/brain_work_fence_test.dart)
- [snapshot_process_recovery_test.dart](../../test/snapshot_process_recovery_test.dart)
- [snapshot_directory_swap_test.dart](../../test/snapshot_directory_swap_test.dart)
- [snapshot_archive_limits_test.dart](../../test/snapshot_archive_limits_test.dart)
- [portable_snapshot_v04256_test.dart](../../test/portable_snapshot_v04256_test.dart)

上述为定位起点，不代表覆盖全部调用者。历史教训及证据见 [回归索引](REGRESSIONS.md)；执行方式见 [验证导航](VERIFICATION.md)。

人工/真机重点：导入中断/重启、磁盘不足、大媒体复制、前后台并行与主设备迁移。
