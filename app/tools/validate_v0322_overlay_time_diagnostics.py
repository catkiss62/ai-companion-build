#!/usr/bin/env python3
"""Static contract checks for v0.32.2 overlay time and redacted diagnostics."""

from pathlib import Path


def read(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise SystemExit(f"ERROR: missing {label}: {needle}")


overlay = read("android/app/src/main/kotlin/com/aicompanion/localfirst/OverlayBubbleService.kt")
runtime = read("android/app/src/main/kotlin/com/aicompanion/localfirst/CompanionRuntimeState.kt")
accessibility = read("android/app/src/main/kotlin/com/aicompanion/localfirst/AccessibilityBridgeService.kt")
system_bridge = read("android/app/src/main/kotlin/com/aicompanion/localfirst/SystemBridge.kt")
dart_bridge = read("lib/core/platform/android_bridge.dart")
system_page = read("lib/features/system/system_page.dart")
diagnostics = read("lib/core/diagnostics/preflight_diagnostics.dart")
database = read("lib/core/database/app_database.dart")
pubspec = read("pubspec.yaml")

if not any(version in pubspec for version in (
    "version: 0.32.2+54", "version: 0.33.0+55", "version: 0.33.1+56", "version: 0.33.2+57", "version: 0.33.3+58", "version: 0.33.4+59", "version: 0.33.5+60", "version: 0.33.6+61", "version: 0.33.7+62", "version: 0.33.9+64", "version: 0.34.0+65", "version: 0.34.1+66", "version: 0.34.2+67",
)):
    raise SystemExit("ERROR: unsupported release version")
require(overlay, 'SimpleDateFormat("HH:mm", Locale.getDefault())', "overlay local time formatter")
require(overlay, 'else "$label · $messageTime"', "overlay time label")
require(database, "'somatic_user_to_ai_events'", "user-to-AI diagnostic count")
require(database, "'somatic_ai_to_self_events'", "AI-to-self diagnostic count")
require(system_bridge, '"accessibilityAuthorized"', "authorization alias")
require(runtime, '"accessibilityLastDisconnectedAt"', "disconnect timestamp export")
require(runtime, "markAccessibilityDisconnected", "disconnect recorder")
require(accessibility, "override fun onUnbind", "accessibility unbind lifecycle")
require(accessibility, 'markAccessibilityDisconnected(this, "unbound")', "unbind reason")
require(accessibility, "noteAccessibilityInterrupted(this)", "interrupt timestamp")
require(dart_bridge, "accessibilityLastDisconnectedAt", "Flutter lifecycle bridge")
require(system_page, "轻视觉已授权但未连接", "user recovery guidance")
require(diagnostics, "accessibilityAuthorized && accessibilityConnected", "two-state preflight")
require(diagnostics, "AI Companion $buildLabel", "dynamic report header")
if "AI Companion v0.31.5+47" in diagnostics:
    raise SystemExit("ERROR: stale hard-coded diagnostic version remains")

print("v0.32.2 overlay time and diagnostic contracts validated.")
