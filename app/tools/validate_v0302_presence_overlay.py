#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    pubspec = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
    assert any(v in pubspec for v in ['version: 0.30.2+38', 'version: 0.30.3+39', 'version: 0.31.0+40', 'version: 0.31.1+41'])

    db = (ROOT / 'lib/core/database/app_database.dart').read_text(encoding='utf-8')
    assert 'static const int schemaVersion = 18;' in db

    runtime = (ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst/CompanionRuntimeState.kt').read_text(encoding='utf-8')
    for token in [
        'overlayInputSuspect', 'overlayLastSystemCoverAt', 'overlayLastCoverRecoveryAt',
        'overlayLastWindowVisibility', 'overlayCoverRecoveryCount',
        'fun noteOverlaySystemCover(reason: String)',
        'fun consumeOverlayInputSuspect(): Boolean',
        'fun noteOverlayCoverRecovered(reason: String)',
    ]:
        assert token in runtime, token

    overlay = (ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt').read_text(encoding='utf-8')
    for token in [
        'requestSystemCoverRecovery(context: Context',
        'scheduleInputChannelRecovery(',
        'system_cover:',
        'OverlayBubbleRoot(context: Context)',
        'onWindowVisibilityChanged(visibility: Int)',
        'CompanionRuntimeState.noteOverlayWindowVisibility(visibility)',
        'cover_recovery:',
        'removeViewImmediate(it)',
    ]:
        assert token in overlay, token

    accessibility = (ROOT / 'android/app/src/main/kotlin/com/aicompanion/localfirst/AccessibilityBridgeService.kt').read_text(encoding='utf-8')
    for token in [
        'AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED',
        'requestSystemCoverRecovery(',
        '"system_surface_return"',
    ]:
        assert token in accessibility, token
    # Recovery reason remains coarse/privacy-safe.
    assert 'requestSystemCoverRecovery(this, sourcePackage)' not in accessibility
    assert 'requestSystemCoverRecovery(this, sanitized)' not in accessibility
    assert 'CompanionRuntimeState.noteOverlaySystemCover("system_surface_entered")' in accessibility
    assert 'isLikelySystemSurface(sourcePackage)' in accessibility

    presence = (ROOT / 'lib/core/presence/presence_intelligence.dart').read_text(encoding='utf-8')
    for token in [
        'class PresenceMomentumPolicy',
        'halfLife = Duration(minutes: 55)',
        'class PresenceIntelligenceEngine',
        "'presence_momentum_score'",
        "topicKey: 'presence:phone_activity'",
        "source: 'presence/phone_activity'",
        'input.userIdleMinutes >= 5',
        'score >= 0.20',
    ]:
        assert token in presence, token
    # No raw Android payload belongs in Presence Momentum.
    for forbidden in ['packageName', 'sourcePackage', 'contentDescription']:
        assert forbidden not in presence, forbidden

    interpreter = (ROOT / 'lib/core/perception/perception_interpreter.dart').read_text(encoding='utf-8')
    assert 'appSwitchesLast30Minutes' in interpreter

    perception = (ROOT / 'lib/core/perception/perception_engine.dart').read_text(encoding='utf-8')
    for token in [
        "import '../presence/presence_intelligence.dart';",
        'PresenceIntelligenceEngine? presence',
        'await presence.integrate(',
        'appSwitchesLast30Minutes: interpretation.appSwitchesLast30Minutes',
    ]:
        assert token in perception, token

    proactive = (ROOT / 'lib/core/desire/proactive_engine.dart').read_text(encoding='utf-8')
    for token in [
        "import '../presence/presence_intelligence.dart';",
        'presence.currentMomentum(now: evaluationStartedAt)',
        'presenceBoost',
        "'presence_last_gate_breakdown'",
        'busyMultiplier = userBusy ? 0.72 : 1.0',
        'sentToday >= 8',
        'sentLastTwoHours >= 2',
        'gateScore < threshold',
    ]:
        assert token in proactive, token
    if any(v in pubspec for v in ['version: 0.31.0+40', 'version: 0.31.1+41']):
        assert 'const presenceBoost = 0.0;' in proactive
        assert "'presenceAppliedToDesire': true" in proactive
    else:
        assert '(presenceMomentum * (userBusy ? 0.055 : 0.095))' in proactive
        assert '.clamp(0.0, 0.085)' in proactive

    diagnostics = (ROOT / 'lib/core/diagnostics/preflight_diagnostics.dart').read_text(encoding='utf-8')
    for token in [
        "'presenceMomentum'", "'presenceSignalClass'", "'presenceLastThoughtAt'",
        "'presenceLastThoughtStrength'", "'lastGateBreakdown'",
        "'inputSuspect'", "'lastSystemCoverAt'", "'lastCoverRecoveryAt'",
        "'coverRecoveryCount'",
        (('AI Companion v0.31.1 · REDACTED LOCAL DIAGNOSTIC REPORT' if 'version: 0.31.1+41' in pubspec else 'AI Companion v0.31.0 · REDACTED LOCAL DIAGNOSTIC REPORT')
         if any(v in pubspec for v in ['version: 0.31.0+40', 'version: 0.31.1+41'])
         else 'AI Companion v0.30.3 · REDACTED LOCAL DIAGNOSTIC REPORT'),
    ]:
        assert token in diagnostics, token

    test = (ROOT / 'test/presence_intelligence_test.dart').read_text(encoding='utf-8')
    for token in [
        'one weak phone event is not enough',
        'repeated coarse activity accumulates gradually',
        'screen off does not inject new phone-activity pressure',
        'recent direct chat suppresses presence thought',
    ]:
        assert token in test, token

    handoff = (ROOT / 'docs/HANDOFF.md').read_text(encoding='utf-8')
    handoff_tokens = ['PresenceMomentumPolicy', 'lastGateBreakdown', 'schema v18']
    handoff_tokens += ((['v0.31.1+41', 'Grounded Desire Core'] if 'version: 0.31.1+41' in pubspec else ['v0.31.0+40', 'Grounded Desire Core'])
                       if any(v in pubspec for v in ['version: 0.31.0+40', 'version: 0.31.1+41'])
                       else ['v0.30.3+39', 'Overlay Regression Repair'])
    for token in handoff_tokens:
        assert token in handoff, token

    print('v0.30.2 Overlay Resume + Presence Intelligence static validation passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
