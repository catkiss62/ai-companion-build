# LingChat pinned visual/audio parity asset notice

This private, non-commercial learning build temporarily includes the pinned
DeepSeek presentation set from:

- Project: LingChat
- Upstream: https://github.com/SlimeBoyOwO/LingChat
- Pinned commit: `eae0d667413e490c3653488d43ce9b4464e07fda`
- Software license in upstream repository: GNU AGPL v3

The upstream README gives additional asset-specific notices which remain controlling and are not replaced by the software license:

- Default character illustrations are drawn by the LingChat developer and must not be misused, commercialized, or used in inappropriate contexts.
- Bubble, interface and sound-effect material includes material identified by upstream as originating from *Blue Archive*.
- Dialogue beep material is identified by upstream as originating from *Undertale*.
- These assets must not be used commercially.

The parity set contains 21 DeepSeek portrait files, two day/night backgrounds,
all 16 upstream expression-effect WebP files and all 23 upstream audio-effect files.
Runtime mappings initially follow the pinned `EMOTION_CONFIG`; dormant
files remain available rather than being silently discarded.

This repository uses these files only for personal study and local testing,
preserves upstream attribution, and does not claim ownership or relicense the
artwork/audio. They are intentionally isolated under `assets/lingchat/` so
they can be replaced with original artwork later.

`tools/fetch_lingchat_visual_assets.sh` records the exact source path, verifies every Git LFS object by SHA-256, and makes the selection reproducible. Emotion audio is disabled by default in the app.


## Day background revision (2026-09-30)

`background/day.webp` is now a daylight edit of the pinned `background/night.webp`,
using the reviewed image-generation preview. The room composition and upstream
attribution remain. The image tool did not expose a verifiable model version.
The generated preview was converted to lossless WebP, 1672x941 RGB; SHA-256:
`6b4296044fd5b882f459e3f66cb586f67d59949a3a49a786a343619149781fb7`.

The committed day asset is the authoritative revised background. The fetch
script above reproduces original upstream inputs and must not be used to
overwrite this reviewed derivative with the original upstream day scene.
Other assets, including the night scene, remain pinned and unchanged.
