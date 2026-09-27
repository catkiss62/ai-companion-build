# Caicai native runtime attribution

Runtime source is copied from `catkiss62/Caicai-Maid-Live2D-Accessory-Lab` commit
`fb04512f940d159ebe13bebc13d2eda5cb54fc9c`. The app retains its tested
renderer, composite model, and autonomous motion code. The standalone test
Activity and system TTS test harness are excluded. This directory carries
the upstream notices and license texts relevant to the copied runtime.

The native Android renderer uses the official Live2D Cubism SDK for Java 5 R5:

- `Live2D/CubismJavaFramework`, pinned as the `Framework` submodule at tag `5-r.5` / commit `c2d420012d004b8e61d4c589bd5c34513122f0ea`.
- `Core/android/Live2DCubismCore.aar`, copied without modification from the official `CubismSdkForJava-5-r.5` distribution. SHA-256: `3f05da57ab855e803000e6353888dd561c47758598c6c0200dcd0109312705f8`.

The Framework remains governed by the Live2D Open Software License referenced in its source headers. Cubism Core remains governed by the Live2D Proprietary Software License; the official distribution's `Core/RedistributableFiles.txt` lists `android/Live2DCubismCore.aar` as redistributable under those terms. See `FRAMEWORK_LICENSE.md` and `CORE_LICENSE.md` here.

No purchased Live2D model, textures, motions, expressions, VTube Studio configuration, or other Sen model assets are included in this repository or APK.

## E.V VTuber motion layer

The optional v0.5.24 motion experiment ports the motion-only VTuber performance layer bundled in
[`siaoic/E.V`](https://github.com/siaoic/E.V), reference commit
`473a3563d91cd4708dd3683d0cff0dc6f522fe52`, subtree `cortico-world-vtuber-main/`.
That upstream component is licensed under GNU AGPL-3.0-or-later.

The original `clips.json` and `vocab.json` are preserved byte-for-byte under
`app/android/app/src/main/assets/ev-vtuber-pack/`. The faithful Java engine ports the motion-related portions
of upstream `src/mixer.ts` and `src/clips.ts`; the Sen-adapted engine is kept as a separate
implementation. Source provenance and the full upstream license are under
`EV_AGPL_LICENSE.txt` here.

## AI Companion host integration (+278)

The 26 original runtime files remain checksum-pinned after stripping three explicitly marked host extension blocks and one update hook. The blocks expose parameter metadata, small form, and sparse motion plans; the original accessory, projection, preset and idle algorithms are unchanged. `CaicaiParameterPlan.java` is new host code. Jev planning follows the semantic-choice/keyframe integration described by `nanlingyin/soullink-emotion-sdk/docs/jev-conversation.md`; no SoulLink source code is copied.
