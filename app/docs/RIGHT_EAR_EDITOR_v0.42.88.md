# v0.42.88+332 右侧耳鳍临时校准

用户18:04取消原提议的修复开关，改为临时编辑；修复显示保持+331，零调整即原+331效果。

入口：Live2D设置 → 调整右侧耳鳍（临时），返回聊天舞台静止预览。水平/垂直范围±100%耳鳍宽度，旋转±45度，提供归零、取消、确认。归零仅预览，确认后保存；取消/返回回滚。编辑期间不改变整模位置或缩放。偏好在caicai_stage，重建和备份恢复复用同一读取器。

右耳所有drawable使用一个最终刚性矩阵，在原耳间约束后应用，避免手调被间距修正抵消。以调整前包围盒中心旋转，位移以该耳宽度为单位，按逻辑舞台宽高比补偿；形态/舞台缩放时偏移一起缩放。左耳、呆毛、尾巴不进入此变换。没有改动顶点或纹理坐标。

诊断state包含right_ear_adjust_x、right_ear_adjust_y、right_ear_adjust_rotation_degrees、right_ear_adjust_units、right_ear_adjust_editing。用户确认保存后导出Live2D诊断即可报值；后续收到确认值再固化默认并删除调整入口，本轮不提前删除。

验证：刚性变换距离守恒、相对位移随耳宽缩放、零值一致；Flutter滑条仅向耳编辑发送预览/确认/取消；Android真实偏好热恢复、回滚及缺省归零。状态CI PASSED / APK READY / TRUE DEVICE PENDING。


交付状态：CI PASSED / APK READY / TRUE DEVICE PENDING。源码2bf43e165f3e9308b58c703301851d1a641bdd69，tree0303e28847ff0d49fdfc30f6bf1f95fb8ea378d7。完整Actions37763443087（build113267104033、native113265230837）成功；专项37763443064成功，452项；全量Flutter1449项、Android原生29项及Java/Kotlin、源码、签名、资源检查通过。新刚性变换测试覆盖距离守恒、不同宽高比、零值、缩放；编辑保存/取消及偏好热恢复通过。未替代用户真机位置验收。

首次完整37761824780被PortableCompanionState.kt固定哈希拦住；复核该文件仅新增rightEarX/rightEarY/rightEarRotation三个便携偏好白名单项后更新钉住值，未修改恢复事务或削弱检查。初次专项37761824661亦通过。复跑完整与专项均成功。

APK：https://github.com/catkiss62/ai-companion-build/releases/download/untagged-7d812a92ed33b5d5c0f7/AI-Companion-v0.42.88-332-Right-Ear-Editor-APK.apk
Release406700602，asset621541522，736807709 bytes。
SHA256：04ff083c54f5e86fb560735fc8d70f037fb841a38bdd112682adaf073c2cbb8b
签名：30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48。保留同签名Draft APK，未发布或合并main。
下一步：用户在Live2D设置→调整右侧耳鳍（临时）调整并确认，导出Live2D诊断；收到确认参数后再固化默认值并删除入口。
