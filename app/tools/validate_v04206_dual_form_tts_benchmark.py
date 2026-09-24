"""Guard the v0.42.6 privacy and profile boundaries without old-session assumptions."""
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def content(path):
    return (ROOT / path).read_text(encoding="utf-8")


def main():
    runtime = content("android/app/src/main/kotlin/com/aicompanion/localfirst/GenieTtsRuntime.kt")
    engine = content("android/app/src/main/kotlin/com/aicompanion/localfirst/NativeTtsEngine.kt")
    preflight = content("android/app/src/main/kotlin/com/aicompanion/localfirst/NativePreflightProbe.kt")
    report = content("lib/core/tts/tts_benchmark.dart")
    form = content("lib/core/personality/playful_form_state.dart")
    preset = content("lib/core/reference/world_book_presets.dart")
    database = content("lib/core/database/app_database.dart")
    assert 'vocoderThreads = 8' in runtime
    assert 'client.configureBenchmarkProfile(profile, diagnostic = true)' in engine
    assert 'client.configureAutoAffinity(oldAffinity)' in engine
    assert '"ttsSessionDiagnostics" to TtsSessionDiagnosticStore.snapshot(context)' not in preflight
    assert 'Clipboard' not in report and '"text" to text' not in engine
    assert 'fixtureHash' in report and "selected.id" in report
    assert "lastTurn == turn" in form and "eventTurn == turn" in form
    assert "小豆丁形态" in form and "用户锁定了当前形态" in form
    assert "外观缩成 Q 版小豆丁" in form and "心智表现也暂时变得孩子气" in form
    assert "嘴硬否认、害羞慌乱地破防" in preset
    assert "06b01d4ed2663c17bfe441af16728d8cdf47729224cf8602012198fe87d87f3e" in database
    print("v0.42.6 dual form and explicit TTS benchmark boundaries passed")


if __name__ == "__main__":
    main()
