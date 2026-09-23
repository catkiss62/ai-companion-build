#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def main() -> None:
    removed_paths = [
        "android/app/libs/Live2DCubismCore.aar",
        "android/app/src/main/assets/com/live2d",
        "android/app/src/main/assets/sen-default-profile-v1.json",
        "android/app/src/main/java/com/catkiss/senlive2dcompanion",
        "android/app/src/main/java/com/live2d/sdk/cubism/framework",
        "android/app/src/main/kotlin/com/aicompanion/localfirst/SenLive2DBridge.kt",
        "android/app/src/main/kotlin/com/catkiss/senlive2dcompanion",
        "android/patches/cubism-java-no-mipmap.patch",
        "lib/core/presentation/sen_live2d_presentation.dart",
        "lib/widgets/sen_live2d_stage.dart",
        "test/sen_live2d_presentation_v04194_test.dart",
    ]
    for relative in removed_paths:
        require(not (ROOT / relative).exists(), f"rolled-back Live2D path remains: {relative}")

    gradle = read("android/app/build.gradle.kts")
    manifest = read("android/app/src/main/AndroidManifest.xml")
    main_activity = read(
        "android/app/src/main/kotlin/com/aicompanion/localfirst/MainActivity.kt"
    )
    wav_player = read(
        "android/app/src/main/kotlin/com/aicompanion/localfirst/WavAudioPlayer.kt"
    )
    chat_page = read("lib/features/chat/chat_page.dart")
    app_shell = read("lib/app.dart")
    cleanup_bridge = read(
        "android/app/src/main/kotlin/com/aicompanion/localfirst/Live2DModelStorageBridge.kt"
    )
    cleanup_client = read("lib/core/platform/live2d_model_storage.dart")
    suite = read("tools/validation_suite.txt")
    workflow = (ROOT.parent / ".github/workflows/build-apk.yml").read_text(
        encoding="utf-8"
    )

    require("Live2DCubismCore" not in gradle, "Cubism Core dependency remains")
    require("glEsVersion" not in manifest, "Live2D GLES manifest feature remains")
    require("SenLive2D" not in main_activity, "Sen bridge remains in MainActivity")
    require("SenLive2D" not in wav_player, "Sen lip-sync hook remains in WavAudioPlayer")
    require("sen_live2d" not in chat_page, "Sen UI/settings remain in ChatPage")
    require("SenLive2DStage" not in chat_page, "Sen stage remains in ChatPage")
    require("resizeToAvoidBottomInset: false" not in app_shell, "Live2D IME override remains")

    require(
        'LEGACY_STORAGE_DIRECTORY = "sen-live2d"' in cleanup_bridge,
        "cleanup bridge does not target the exact legacy model directory",
    )
    require("storageRoot.parentFile == filesRoot" in cleanup_bridge, "cleanup root guard missing")
    require("root.listFiles()?.forEach(::deleteTree)" in cleanup_bridge, "recursive model cleanup missing")
    require("isSymbolicLink()" in cleanup_bridge, "symlink-safe model cleanup missing")
    require("LEGACY_PREFERENCES" in cleanup_bridge, "legacy model index cleanup missing")
    require("clearImportedModels" in cleanup_bridge, "native cleanup method missing")
    require("ai_companion/live2d_model_storage" in cleanup_client, "Dart cleanup channel missing")
    require("清除 Live2D 模型包" in chat_page, "persistent cleanup control missing")
    require("确认清除" in chat_page, "destructive cleanup confirmation missing")

    require("version: 0.42.2+246" in read("pubspec.yaml"), "build version mismatch")
    require("v0.42.2+246" in workflow, "workflow version mismatch")
    require("forbidden_live2d" in workflow, "APK Live2D absence gate missing")
    require(
        "tools/validate_v04197_natural_reply_liveness.py" in suite,
        "natural-reply validator was not preserved",
    )
    require(
        "tools/validate_v04200_live2d_clean_rollback.py" in suite,
        "rollback validator is not registered",
    )
    for validator in (
        "tools/validate_v04143_phase3b_question_autonomy.py",
        "tools/validate_v04145_sticker_expression.py",
        "tools/validate_v04147_user_sticker_image_send.py",
        "tools/validate_v04148_agent_image_reliability.py",
        "tools/validate_v04149_subjective_search_humor.py",
        "tools/validate_v04150_agent_v2_bounded_loop.py",
    ):
        require(
            "0\\.42\\.2\\+246" in read(validator),
            f"current version missing from {validator}",
        )

    print("v0.42.0 Live2D clean rollback remains preserved in the current build")


if __name__ == "__main__":
    main()
