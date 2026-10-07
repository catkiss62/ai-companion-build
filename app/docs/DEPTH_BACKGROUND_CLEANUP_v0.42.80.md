# +324 · 立体背景与旧连接清理

2026-10-07 16:22用户授权开始。基线+323/2fc551f，分支agent/v04280-depth-background-cleanup，目标0.42.80+324。

## 范围与顺序
1. 完整审查TransferPage、Nearby原生传输、Dart/原生桥及权限、快照恢复和主设备身份共用链路。删除旧Nearby入口/传输专用实现；保留.aibackup保存恢复、旧包兼容、手动换机恢复、原子恢复与取消围栏。不清除存量数据库或改变schema。
2. 日/夜原背景保留，增加背景深度视差、开关和强度。文字/按钮稳定，人物绑定及输入法尺寸不改。前台可见才读取姿态、重新进入校准中心、平滑限幅、传感器缺失保持静态。原生Live2D与普通立绘背景均核对。
3. 两项独立提交、同一测试APK；只开发分支，不合并main/正式发布。

## 用户新决定
+323小豆丁恢复本体后的错误自称已真机解决。长期梦境/愿望等继续观察。旧手机平板伴随端路线取消，未来独立平板陪玩App显示同一条台词并与手机聊天同步，另案实现。

## 验证计划
- 保留备份/恢复/手动换机与旧包兼容行为测试，核对取消、失败回滚与主设备身份；移除仅针对被删除Nearby功能的历史断言并记录原因，共用断言保留。
- 姿态方向、校准、限幅、生命周期/禁用释放；深度背景方向与越界、GL上下文恢复、原生资源释放、原有Live2D截图/输入法测试。
- Flutter analyze、全量行为测试、原生烟测、源码/资源/签名检查。同签名APK交付后由用户验证实机观感和耗电，不把模拟器视为真机。

## 状态
IMPLEMENTATION IN PROGRESS / CI PENDING / APK PENDING / TRUE DEVICE PENDING。

## 连接清理审查记录
已完整阅读TransferPage、NearbyTransferManager、NativePreflightProbe、SnapshotService、SnapshotRestoreCoordinator、TransferStateIdentity及缓存清理；定点完整阅读AppDatabase的状态身份/冻结/取消/手动激活/手动导出事务，桥接的Nearby及共用权限生命周期和备份方法边界、诊断调用者。
- 删除Nearby发送/接收/ACK/超时/发现路径、专用EventChannel/权限请求、Google Nearby依赖、Nearby自检与日志记录器。通知权限与原文件选择器共用回调保留。
- .aibackup、旧文件夹备份、.aicomp手动换机仍在同一页面，改名“备份与恢复”；状态库、SnapshotService/恢复协调器/原生备份与加密不改。协议中历史encryption字段和旧缓存前缀保留以兼容旧包。
- NativeEventStore的旧状态围栏辅助函数暂保留，与共用身份源码和历史协议检查同在；没有Nearby组件或入口可再调用它，避免把本批扩大成身份机制重构。
- validate_transfer_kotlin_v26仅删除已退役Nearby类的编译目标；真实NativeEventStore、手动加密编译检查保留。旧测试桩后续同步清理，不删除备份/恢复断言。
