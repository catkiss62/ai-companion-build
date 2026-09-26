Experimental animation test assets from
https://github.com/MerZlin/dsh-pet-indesktop at commit
2786c156dc61774a4195d6930806bb0471b59884.

Copyright (c) 2026 Merzlin. MIT License; see LICENSE.txt in this directory.

- hum: `assets/characters/shenshen/videos/random/悠闲哼歌.webm`
- stretch: `assets/characters/shenshen/videos/random/超大伸懒腰.webm`
- cube: `assets/characters/shenshen/videos/random/原地专心玩魔方.webm`
- stand: `assets/characters/shenshen/videos/idle/待机呼吸休闲.webm`
- click: `assets/characters/shenshen/videos/click/点击回应-元气挥手.webm`

Frames were decoded with FFmpeg/libvpx-vp9 preserving alpha and every source
frame at 24 fps (including the terminal frame at 10.000 seconds),
cropped from the 640×360 transparent canvas at x=140 to a 360×360 square,
resized to 224×224 (240×240 for click), and encoded to still WebP at quality
70 (75 for click). Each set contains all 241 original frames from 0 to 10
seconds of source time; playback runs at 1.5× speed. Frames are packed in
source order as `PET241\0` followed by repeated big-endian 32-bit byte length
and complete WebP bytes, then split into sequential 96 KiB `.bin` parts. No
frame is removed by this packaging. The original
videos were not modified upstream.
