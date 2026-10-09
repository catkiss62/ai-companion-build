# v0.42.90+334 旧桌宠修图

基于 +333 右耳定版，接入用户 2026-10-09 上传的58张旧动作306修图与独立sleepy_yawn_306。独立yawn与ZIP内旧图不同，以独立文件为准。177个画布尺寸和目标路径保持，59张原件不重编码；118张小中档从对应306原件单次预乘Alpha Lanczos缩小。原件及产物都在 `app/asset_packs/dafeiyu_retouched/frames/`，详细维护流程见该目录README。

读取桌宠动作清单、播放器、帧缓存、视图缩放、原包恢复和APK资源检查后，选择构建时精确替换。冻结分片包不改，历史校验先执行；随后应用修图，再进行Kotlin测试和APK构建。运行时播放器代码、Live2D、动作状态/帧数/时序/镜像/锚点、缩放设置和新动画均不改。不会把修图误当新动作或改变触发频率。

校验覆盖：原件字节、所有目标尺寸/RGBA/路径唯一性、59帧每档齐全、与现有实际使用帧集合一致、未知目标拒绝、重复应用、原始417文件仅174张变化且action manifest不变、最终APK所有源包文件与177张修订图精确一致。持续睡姿使用sleep_enter最后一帧，向右走路镜像左侧，因此不替换四组未播放的上游素材。

状态：CI PASSED / APK READY / TRUE DEVICE PENDING。真机需查看三档白边、补全部位、入睡/醒来和走路衔接；此文不把静态检查当作真机通过。

本地验证：143/150源码门通过；余7项缺少稀疏检出的既有资源或kotlinc，留完整CI。真实原包417文件校验通过；资源替换试运行验证174源包PNG变化、243文件字节保持、原manifest不变，另3个yawn正确。未知目标拒绝、重复应用和构造打包字节/旧帧拒绝验证通过。该构造包仅为资源流程测试，不冒称Android APK真机结果。

历史推送状态：PUSH BLOCKED（用户授权后已解除）。自动审核拒绝公开仓库的新图片推送（素材对外授权不明确）；本地完成，等待明确授权后推送agent/v04290-pet-retouch并触发CI。尚无本版APK或CI通过声明。

2026-10-09 19:12 用户明确批准本批图片及改动的指定分支推送和APK构建，授权阻塞解除，CI PENDING。

跨窗口续传检查：205个变更文件已存140个Git blob，65项待传；目标远端ref尚未建立，Actions尚未启动。检查点205项的路径/哈希均与本地一致，177图校验与实际播放帧覆盖校验复跑通过。沿用既有授权续传，每个成功项保存检查点；最终tree与本地HEAD一致后建立目标分支并启动完整CI。顶部状态仍IMPLEMENTED / CI PENDING / TRUE DEVICE PENDING。

续传205/205完成；远端0c48f2f的tree359c9e3与本地863b743一致。追加本地总账检查发现新接班记录使顶部索引100448字节超100KB门槛，完整保留+308原文移入正式记录并留下索引；没有放宽检查。补上既有专项workflow的+334分支触发，使修正提交执行完整和专项CI。桌宠PNG无需重传。

首轮完整CI37936112594在最终旧哈欠哈希段失败：它仍使用修图前dcbbcba4/f6659dc5/141a8840。150源码门、1447全量Flutter、29原生、Kotlin/Java、release编译、177修订图/417文件逐字节与稳定签名此前均已通过；专项37936112662通过450项。故仍CI PENDING / APK PENDING。改为从已审核manifest读取精确三图哈希，保留固定尺寸和恰好三档集合；冻结原图检查在覆盖前继续使用旧钉住值。实际workflow验证段需确认新版接受、旧图拒绝、缺项拒绝后重跑完整CI。

## 最终交付

源码1f6de26c69958a59db9569c10f5a5e7b759c2c73，treedde723b7cadfdb8149acabc030b5c1e6f2405426。完整Actions37939853983、专项37939853995成功：150源码门、1447全量Flutter、450专项、29原生及Kotlin/Java、177修订PNG与417源包全文件逐字节、完整96 clips/23013 frames、稳定签名均通过。首轮旧哈欠哈希冲突已通过读取审核manifest修正，未跳过校验；失败和取消运行证据保留在唯一总账。

APK：https://github.com/catkiss62/ai-companion-build/releases/download/untagged-4cf0810a030b12182bda/AI-Companion-v0.42.90-334-Pet-Retouch-APK.apk
下载页：https://github.com/catkiss62/ai-companion-build/releases/tag/untagged-4cf0810a030b12182bda
Draft Release407936478 / asset625177441 / 736803277 bytes。SHA-256：a5c064e350be6b40595e5d3c7a7fe50752888f903f0959597f0b31a554e0f113。CI、成功monitor与上传资产digest一致。
签名：30:5E:B3:D8:09:83:B9:63:C6:48:18:DD:F1:AD:56:1F:27:9D:E6:D4:7B:3E:D2:C7:81:AD:A4:48:C7:C2:51:48，可同签名覆盖安装。

CI PASSED / APK READY / TRUE DEVICE PENDING。用户真机重点验证三档透明边缘、补全细节、入睡/醒来和走路衔接；未将静态或模拟器验证当成实体设备验收。原PNG和生成图均保留在维护目录，后续直接改306并再生成即可。
