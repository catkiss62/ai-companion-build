# v0.42.89+333 右耳位置定版

用户在+332真机编辑后确认画面，导出诊断中已保存的数值为x=-0.075、y=0.04、rotation=9.45°、editing=false。截图显示一位小数9.4°，此处按诊断实际精度固化9.45°。

右耳所有网格共享同一个变换，以原耳宽为位移单位：x负值向左，y正值向上；逆时针旋转9.45°。保留+331像素比例修正以及耳间距约束后的应用顺序。数值固定在渲染器变换层，不依赖caicai_stage偏好。删除临时Live2D设置按钮、编辑控件、原生预览命令、保存/恢复读写。旧+332存档的三个耳值仍可通过备份白名单验证并导入，但新渲染器忽略，不会二次叠加。新导出诊断state含right_ear_default_x/y/rotation_degrees及单位说明。

验证范围：Java几何测试覆盖多个屏幕宽高比、耳尺寸、中心位移与刚性长度守恒；Android恢复测试验证带旧耳值的存档可导入且无动态右耳字段；Flutter原阶段编辑仍可确认/取消。源代码检查141/149本地通过，8项依赖稀疏签出缺失资源或kotlinc，交完整CI。状态CI PASSED / APK READY / TRUE DEVICE PENDING。


最终交付：CI PASSED / APK READY / TRUE DEVICE PENDING。源码a3a5b15051294b1ffa792bb4c06d1d9b9fc16e9f，源树b4a00efa8319ff55fb57866fd224b544e8b5a021。完整Actions37805027819（build job113409859915、native job113406994251）和专项Actions37805027930（job113406946098）均成功；149源码门、1447全量Flutter、450专项、29 Android35原生及Java/Kotlin通过，APK签名/资源校验通过。
APK：https://github.com/catkiss62/ai-companion-build/releases/download/untagged-2b24ab65170a4acaa614/AI-Companion-v0.42.89-333-Right-Ear-Baked-APK.apk
Release407040117，asset622356758，736802525 bytes，SHA256：3f5ef4d82b7ef68231a183dfd8f229b85ec674d4623a7f770043071e43c94dbf。
签名：30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48。保留同签名Draft APK，未发布或合并main。用户给出的+332画面即参数基准，+333安装升级后显示和入口移除仍待用户真机核对。
