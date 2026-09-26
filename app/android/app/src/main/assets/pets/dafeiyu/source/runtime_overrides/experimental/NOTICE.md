Experimental animation test assets from
https://github.com/MerZlin/dsh-pet-indesktop at commit
2786c156dc61774a4195d6930806bb0471b59884.

Copyright (c) 2026 Merzlin. MIT License; see LICENSE.txt in this directory.

- hum: `assets/characters/shenshen/videos/random/悠闲哼歌.webm`
- stretch: `assets/characters/shenshen/videos/random/超大伸懒腰.webm`
- cube: `assets/characters/shenshen/videos/random/原地专心玩魔方.webm`
- stand: `assets/characters/shenshen/videos/idle/待机呼吸休闲.webm`
- click: `assets/characters/shenshen/videos/click/点击回应-元气挥手.webm`

Frames were decoded with FFmpeg/libvpx-vp9 preserving alpha, sampled at 4 fps
(6 fps for click),
cropped from the 640×360 transparent canvas at x=140 to a 360×360 square,
resized to 224×224 (240×240 for click), and encoded to still WebP at quality
65 (70 for click). Each idle set is 40 frames and click is 60 frames, sampled
from 10 seconds of source time; playback runs at 1.5× speed. The original
videos were not modified upstream.
