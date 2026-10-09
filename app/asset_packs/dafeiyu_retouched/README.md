# 当前使用的旧桌宠图片

这就是 2026-10-09 用户抠白边、补全缺失部位后的有效图片目录，GitHub 可以直接打开 PNG。

- `frames/<素材名>/*_306*.png`：59 张用户修图原件，字节原样保留。`yawning` 使用单独上传的 PNG，ZIP 中的同名旧图未使用。
- 同目录的 `*_238*.png`、`*_187*.png`：从该帧 306 原件单次缩小生成，共 118 张。
- `manifest.json`：每帧原件、三档目标路径、原始/新文件 SHA-256 和实际画布尺寸的完整映射。
- 文件名中的 187/238/306 是尺寸档，不一定等于含透明留白的画布高度。画布、角色位置、帧顺序均不可自动裁剪或重新排列。

## 下次修图

1. 直接修改本目录对应的 306 PNG，保留原文件名、画布和 RGBA 透明通道。
2. 在仓库根目录执行 `python3 -m pip install Pillow==12.3.0`，然后 `python3 app/tools/prepare_retouched_pet_frames.py --regenerate`。
3. 审阅 306 原件与两档缩图；更新本说明的来源记录，提交图片和 manifest 一起构建。

缩图使用预乘 Alpha 的 LANCZOS，一次直接从 306 到目标画布；不裁边、不锐化、不重新生图，306 原件不会被重编码。较小图片的像素数更少，不能保留与大图完全等量的细节。

## 构建顺序

冻结包 `../dafeiyu_private.parts/` 仍是原始 417 文件的完整历史来源。CI 先还原并运行旧包校验，再执行 `prepare_retouched_pet_frames.py --apply`，在相同路径覆盖 177 张 PNG（174 张源包图和 3 张 yawn）。原 actions.json、帧数、时序、方向镜像、锚点及播放器不变。

本地需先还原完整旧包和原始 yawning 文件。`--apply` 对每张目标的旧/新哈希和尺寸预检；不接受未知图片，重复应用可用。历史 frozen-pack validator 只适用于应用修订前；已应用后重新验证冻结包时应从干净检出恢复，勿把旧包验证失败当作修订损坏。

最终 `--verify-apk <APK>` 核对 177 张新图片哈希，并核对所有 417 个源包文件的打包字节。运行时无需 Pillow 或任何额外判断。

## 常用动作位置

待机 `idle_front`；背面 `idle_back`；眨眼 `idle_blink`；观察 `idle_glance`；发呆 `idle_think`；走路 `walk_side`、`walk_start_left`、`walk_stop_left`；慢行侧站 `walk_side_stand`；开心 `happy`；摸头 `head_pat`；说话 `talk`；生气 `angry`；被戳 `poke_react`；尾巴 `tail_react`；进食 `eat`；扫地 `sweep`；入睡和持续睡姿 `sleep_enter`；醒来 `sleep_wake`；抓取 `dragging`；释放 `released_airborne`；落下 `falling`；着陆 `landing`；眩晕 `dizzy`；打哈欠 `yawning`。

APK中的打哈欠三档校验也读取本manifest的精确新哈希，仍独立核对原固定画布和恰好三档；不再手工维护第二套旧哈希。冻结原图检查保持在修订应用前执行。
