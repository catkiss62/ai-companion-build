# QQ private bridge 0.1

独立 Dart 子项目；不依赖 Flutter、AppDatabase、MemoryExtractor、Dream、Agent 或 TTS。主 App 仅通过宿主适配器提供只读上下文和正文生成。移除设置入口、原生独立 Service 与宿主适配器即可卸下；不修改主聊天流程。

首版只接绑定用户的 C2C 文字。群聊与其他私聊在记忆查询前丢弃。QQ 的短期会话、去重与投递记录保存到独立目录，不写主聊天表、长期记忆、关系、梦境或作品状态；也不自动转发 App 主动消息。尚未接入图片/表情/语音收发，不把平台支持当作已完成。

协议参考腾讯 MIT SDK `tencent-connect/qqbot-nodejs`（核查 commit 429a0f1b798f3b0fcef3679e207dbc0469a1df2d）与增强插件 `zaofan-make/dsh-qqbot`（核查 commit 5f455e2a057210e2cdf650d2da5750a17224c438）。采用官方 HTTP + WebSocket，不运行 dsh/Node、无障碍点击或个人 QQ 客户端协议。

多媒体可行性：官方 C2C 附件含图片、`voice_wav_url` 和可选 `asr_refer_text`；SDK 音频模块支持 WAV/MP3/SILK 直传。App 已有视觉、图片表情包和 WAV 合成。后续必须独立核验下载/上传、音频任务所有权与投递回执；当前子项目没有这些能力。
