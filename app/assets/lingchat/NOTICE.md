# LingChat temporary visual/audio asset notice

This private, non-commercial learning build temporarily includes selected assets from:

- Project: LingChat
- Upstream: https://github.com/SlimeBoyOwO/LingChat
- Pinned commit: `eae0d667413e490c3653488d43ce9b4464e07fda`
- Software license in upstream repository: GNU AGPL v3

The upstream README gives additional asset-specific notices which remain controlling and are not replaced by the software license:

- Default character illustrations are drawn by the LingChat developer and must not be misused, commercialized, or used in inappropriate contexts.
- Bubble, interface and sound-effect material includes material identified by upstream as originating from *Blue Archive*.
- Dialogue beep material is identified by upstream as originating from *Undertale*.
- These assets must not be used commercially.

This repository uses the selected files only for personal study and local testing, preserves upstream attribution, and does not claim ownership or relicense the artwork/audio. They are intentionally isolated under `assets/lingchat/` so they can be replaced with original artwork later.

`tools/fetch_lingchat_visual_assets.sh` records the exact source path, verifies every Git LFS object by SHA-256, and makes the selection reproducible. Emotion audio is disabled by default in the app.
