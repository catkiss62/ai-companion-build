# AI Companion · v0.31.5 Clean Freeze

日期：2026-08-14（Asia/Tokyo）  
冻结基线：`main@0d7721349f835ad334dbb702d9adf7b0974d0175`  
应用：`v0.31.5+47`  
SQLite：schema 20

## 1. 冻结理由

- GitHub Actions run #31 已成功完成 +47 补丁应用、静态验证、Flutter analyze、tests 与 release APK。
- Actions 随后把完整 +47 源码提交进 `app/`，当前 `app/` 已是源码真源。
- 用户提供的真机脱敏诊断确认 `versionName=0.31.5`、`versionCode=47`、schema 20、Active Brain 正常且无运行错误。
- 根目录升级补丁和项目文档 ZIP 已完成历史使命；继续把它们留作当前构建输入会造成误操作。
- 原 workflow 仍要求从 +46 应用 +47 补丁；在当前 +47 基线上再次运行会失败，不再适合作为构建入口。

## 2. 新的仓库契约

```text
app/                         唯一产品源码真源
.github/workflows/build-apk.yml
                             从当前 app/ 直接验证和构建
app/docs/                    架构、状态、任务和方案文档
Git history                  历史补丁与升级过程的恢复来源
```

常规构建不得：

- 应用根目录 patch；
- 解压项目文档 ZIP 覆盖 `app/docs/`；
- 在构建过程中自动提交源码；
- 假设当前基线仍是 +46。

## 3. 从根目录移除的历史输入

以下文件均已通过对应成功 Actions 运行进入 `app/`，删除后仍可从 Git 历史恢复：

- `v0301-overlay-touch-recovery.patch`
- `v0302-overlay-resume-presence.patch`
- `v0303-overlay-regression-repair.patch`
- `v0310-grounded-desire-core.patch`
- `v0311-proactive-grounding-timestamps.patch`
- `v0312-companion-voice-recovery.patch`
- `v0312-43-companion-voice-hotfix.patch`
- `v0312-44-streaming-inner-rich-voice.patch`
- `v0313-overlay-file-picker-recovery.patch`
- `v0314-grounded-desire-growth.patch`
- `v0314-project-docs.zip`
- `v0315-live-context-self-seed.patch`
- `v0315-project-docs.zip`

旧 `.github/workflows/build-v028-apk.yml` 同时退役，改为 `build-apk.yml`。

## 4. 新 workflow

顺序：

1. checkout 当前分支；
2. 确认 `app/pubspec.yaml` 为 `0.31.5+47`、数据库 schema 20；
3. 安装 Java 17 / Flutter 3.44.9，并为本次运行生成一次性测试签名；
4. 执行当前 validators；
5. `flutter pub get`；
6. `flutter analyze`；
7. `flutter test`；
8. `flutter build apk --release`；
9. 校验原生库字节与 TTS A2 黄金前缀；
10. 生成 SHA-256 并上传 APK artifact。

workflow 只读仓库，不再拥有 `contents: write`，也不自动 push。

旧 workflow 曾把测试 `debug.keystore` 直接写在 YAML 中。Clean Freeze 不复制该凭据，也不把任何私钥、base64 或指纹重新固化到 Git。

用户明确说明：当前项目所有对话与状态都只是半成品测试数据，每次安装都可先卸载 App，不要求覆盖安装或存档保留。因此新 workflow 每次运行生成有效期 30 天的一次性测试 key，构建完成即随 runner 销毁，不需要 GitHub Secrets。由此产生的 APK 必须卸载旧测试包后安装；正式发布前另行建立长期 release signing，不能使用该临时签名。

## 5. 已知边界

- 本次只整理仓库形态，不改变 Dart/Kotlin/SQLite 运行逻辑。
- Overlay file-picker 与全屏游戏问题继续冻结。
- TTS A2 运行基线不变。
- 规则 01/03 合并是 Clean Freeze 后的下一项独立 schema 迁移，不混入本次整理。
- 真正停止生成、通知音、感官、联网、桌宠与屏幕陪伴仍按任务账推进。

## 6. 回滚

- 所有删除均为 Git 跟踪文件，可从基线 commit 或历史 commit 恢复。
- 若新 workflow 构建失败，优先修正当前 `app/` 或 workflow；不得恢复“构建时应用旧补丁”的长期模式。
- 只有在需要重放历史升级过程做取证时，才从 Git 历史临时取回单个 patch。
