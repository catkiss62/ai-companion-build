#!/usr/bin/env python3
"""Pin the tested Caicai runtime and its non-model resources across app upgrades."""

import hashlib
import re
from pathlib import Path


APP = Path(__file__).resolve().parents[1]
ANDROID = APP / "android/app"


def require(condition: bool, detail: str) -> None:
    if not condition:
        raise SystemExit(detail)


def tree_digest(relative: str, expected_count: int, expected_hash: str) -> None:
    root = ANDROID / relative
    # Host-owned additions are tested separately; the imported source count/hash stays pinned.
    files = sorted(path for path in root.rglob("*") if path.is_file()
                   and path.name not in {"CubismShaderAndroid.java", "CubismRendererAndroid.java", "CaicaiParameterPlan.java", "CaicaiIdleMotion.java", "CaicaiRootTransform.java", "CaicaiFaceMotion.java", "CaicaiCompanionView.java", "CaicaiTextureSurface.java", "CaicaiSceneCamera.java", "CaicaiStageBackground.java", "CaicaiHeadPat.java", "CaicaiEmotionLease.java", "CaicaiFrameDiagnostics.java", "CaicaiHeadPose.java", "CaicaiRootTiltSmoother.java", "RoomMotionInterpolator.java", "CaicaiEarRotation.java"})
    digest = hashlib.sha256()
    for path in files:
        digest.update(str(path.relative_to(root)).encode())
        digest.update(b"\0")
        data = path.read_bytes()
        if path.name in {"SenCompanionView.java", "SenRenderer.java", "SenLive2DModel.java", "SenPerformanceEngine.java"}:
            # Pin original renderer and accessory math; allow reviewed host additions.
            text = data.decode()
            text = re.sub(r"^[ \t]*// BEGIN AI_COMPANION_HOST_EXTENSION\n.*?^[ \t]*// END AI_COMPANION_HOST_EXTENSION\n", "", text, flags=re.S | re.M)
            text = re.sub(r"^.*// AI_COMPANION_HOST_PLAN_HOOK\n", "", text, flags=re.M)
            data = text.encode()
        digest.update(data)
        digest.update(b"\0")
    require(len(files) == expected_count and digest.hexdigest() == expected_hash,
            f"Caicai source drift: {relative}")


def file_digest(relative: str, expected_hash: str) -> None:
    path = ANDROID / relative
    require(path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() == expected_hash,
            f"Caicai resource drift: {relative}")


def main() -> None:
    # Caicai lab fb04512f (framework submodule c2d4200). Test-only Activity
    # and system-TTS harness are excluded. The Cubism renderer's drawable
    # filter and shader's no-mipmap filter are the lab's two required patches.
    # +331 separates overlay-face / wink exclusivity (behavior tested).
    # +293 also guards the authored combo Wink's arm preset ownership.
    # Keep pinning the reviewed source tree after that conflict fix.
    tree_digest("src/main/java/com/catkiss/senlive2dcompanion", 26,
                "98dd4dba5e68fc9ba3eccc8165d24fac63085fee0e8a429ddbd53085be42f9f5")
    tree_digest("src/main/java/com/live2d/sdk/cubism/framework", 103,
                "0b74f27d46c5e5988d798095e0139728bd2fd58386b854cbb41fcc138a3686ea")
    tree_digest("src/main/assets/com/live2d/sdk/cubism/framework", 36,
                "a2aff051539ed8ec1fe556e87da1222c115787cee57510597a781c54be688386")
    for name, digest in {
        "libs/Live2DCubismCore.aar": "3f05da57ab855e803000e6353888dd561c47758598c6c0200dcd0109312705f8",
        "src/main/java/com/live2d/sdk/cubism/framework/rendering/android/CubismRendererAndroid.java":
            "1d6ceb0b28bcdc06a35462a1e87f6fb0cdafdc2b3e7fcd501fb3056fa7c84728",
        "src/main/java/com/live2d/sdk/cubism/framework/rendering/android/CubismShaderAndroid.java":
            "59458adb20f547d71c4847c54454aa7517d79b0e21fe22c029090c31130827b0",
        "src/main/assets/ev-vtuber-pack/clips.json": "bcbb302acddb02fb034df60ef3748304f79365a1f4b18d324165605cc0e66240",
        "src/main/assets/ev-vtuber-pack/vocab.json": "fff242375d0d5435c05f508f1e77b5b885041468f0825eefda2e11fa2c4321a6",
    }.items():
        file_digest(name, digest)
    shader = (ANDROID / "src/main/java/com/live2d/sdk/cubism/framework/rendering/android"
             / "CubismShaderAndroid.java").read_text()
    require("GL_LINEAR_MIPMAP_LINEAR" not in shader and "GL_LINEAR" in shader,
            "Caicai texture filtering again requires absent mipmap levels")
    host = (ANDROID / "src/main/kotlin/com/catkiss/senlive2dcompanion/CaicaiPlatformView.kt").read_text()
    require("SenMotionMode.EV_FAITHFUL.id" in host and
            "CompositeOutfit.MAID_WITH_SEN_ACCESSORIES.id" in host and
            "setFrontHairPoint(FRONT_HAIR_POINT)" in host,
            "Caicai lab's accepted rendering configuration changed")
    require("setGeometryConstraintEnabled(true)" in host and
            "setFrontHairExperimentEnabled(true)" in host,
            "Caicai three-accessory geometry configuration changed")
    require(not list((ANDROID / "src/main/assets").rglob("*.moc3")),
            "private model weights must be imported on device")
    require((APP / "docs/third_party/caicai-live2d/THIRD_PARTY_NOTICES.md").is_file(),
            "Caicai runtime source attribution is missing")
    print("Caicai native idle source and assets pinned; model remains private.")


if __name__ == "__main__":
    main()
