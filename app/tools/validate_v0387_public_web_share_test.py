#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise SystemExit(f"missing {label}: {needle}")


pubspec = read("pubspec.yaml")
policy = read("lib/core/autonomy/public_web_share_policy.dart")
coordinator = read("lib/core/autonomy/public_web_share_coordinator.dart")
database = read("lib/core/database/app_database.dart")
system_page = read("lib/features/system/system_page.dart")
settings = read("lib/features/settings/settings_page.dart")
reference = read("lib/core/reference/reference_library.dart")
rules = read("lib/core/rules/rule_layer_defaults.dart")
reference_doc = read("docs/REFERENCE_LIBRARY.md")
workflow = read("../.github/workflows/build-apk.yml")

require(pubspec, "version: 0.38.7+106", "release version")
assert any(\n    token in database\n    for token in (\n        "static const int schemaVersion = 32;",\n        "static const int schemaVersion = 33;",\n    )\n), "compatible schema baseline"
require(database, "activeReadyPublicWebShareCandidate", "ready candidate lookup")
require(database, "clearDiagnosticPublicWebShareFixture", "repeat fixture cleanup")
require(database, "NOT EXISTS (", "orphan Thought cleanup")
require(database, "beginPublicWebShareTest", "test attempt telemetry")
require(database, "completePublicWebShareTest", "test terminal telemetry")
require(coordinator, "PublicWebShareTestPolicy.existingReadySource", "existing ready reuse")
require(coordinator, "PublicWebShareTestPolicy.diagnosticSeededSource", "local fixture source")
require(coordinator, "state: 'stale_ready'", "stale ready diagnosis")
require(system_page, "await db.beginPublicWebShareTest()", "test attempt start")
require(system_page, "await db.completePublicWebShareTest(", "test terminal result")
require(system_page, "forcedThoughtIdForDebug: staged.thoughtId", "bound Thought evaluation")
require(policy, "class PublicWebShareTestPolicy", "privacy-safe outcome policy")
for category in (
    "model_wait",
    "proactive_lease",
    "chat_turn",
    "api_key",
    "grounding_guard",
    "service_template_guard",
):
    require(policy + database, category, f"stable outcome category {category}")

clear_pos = coordinator.index("clearDiagnosticPublicWebShareFixture")
ready_pos = coordinator.index("activeReadyPublicWebShareCandidate")
seed_pos = coordinator.index("seedDiagnosticPublicWebShareCandidate")
if not (clear_pos < ready_pos < seed_pos):
    raise SystemExit("diagnostic test must clean, reuse ready, then seed")

for field in (
    "'attemptCount'",
    "'lastResult'",
    "'candidateSource'",
    "'reachedEvaluation'",
    "'modelDecisionReached'",
    "'blockCategory'",
    "'reasonTextIncluded': false",
    "'modelOutputIncluded': false",
    "'promptIncluded': false",
):
    require(database, field, f"redacted test diagnostic {field}")

for text, label in (
    (settings, "settings UI"),
    (reference, "reference prompt"),
    (rules, "reference rules"),
    (reference_doc, "reference documentation"),
):
    if "旧 index" in text or "旧 Index" in text or "旧index" in text:
        raise SystemExit(f"legacy index wording remains in {label}")

require(settings, "title: const Text('参考资料')", "reference UI title")
require(
    reference,
    "用户导入的人设/设定参考资料",
    "reference prompt semantics",
)
require(
    workflow,
    "validate_v0387_public_web_share_test.py",
    "workflow validator",
)
require(
    workflow,
    "AI-Companion-v0.38.7-106-Public-Web-Share-Test-Repair-APK",
    "APK artifact",
)

print("v0.38.7 public web share true-device test repair validation passed")
