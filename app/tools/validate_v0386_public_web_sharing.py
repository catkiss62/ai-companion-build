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
thought = read("lib/core/models/thought.dart")
prompt = read("lib/core/ai/prompt_builder.dart")
proactive = read("lib/core/desire/proactive_engine.dart")
presentation = read("lib/core/desire/proactive_presentation.dart")
system_page = read("lib/features/system/system_page.dart")
workflow = read("../.github/workflows/build-apk.yml")

require(pubspec, "version: 0.38.7+106", "forward-compatible release version")
require(database, "static const int schemaVersion = 32;", "unchanged schema")
require(policy, "thoughtText", "content-free Thought contract")
require(policy, "public_web_candidate:", "candidate provenance prefix")
require(coordinator, "desire.feedThought", "existing Thought ingress")
require(coordinator, "incomingStrength: 0.62", "bounded share Thought strength")
require(database, "claimNextPublicWebCandidateForSharing", "durable candidate claim")
require(database, "action_run_id = ? AND id != ?", "one candidate per discovery")
for state in ("share_staging", "share_ready", "shared", "declined"):
    require(database, state, f"candidate lifecycle {state}")
require(database, "lifecycle_state = 'unread'", "unread-only candidate promotion")
require(database, "source LIKE 'public_web_candidate:%'", "bound Thought diagnostic")
require(thought, "ThoughtProvenance.publicWebCandidate", "web Thought provenance")
require(proactive, "publicWebSharing.stageNextCandidate", "heartbeat staging")
require(proactive, "forcedThoughtIdForDebug", "exact diagnostic Thought")
require(proactive, "webShareContract", "persona share-or-WAIT contract")
require(proactive, "publicWebSharing.markDeclined", "WAIT decline outcome")
require(proactive, "publicWebSharing.markShared", "sent share outcome")
require(presentation, "intent.reasonSource.startsWith('public_web_candidate:')", "social share classification")
require(prompt, "safety=untrusted_public", "untrusted web prompt boundary")
require(system_page, "测试网页分享闭环", "true-device probe")
require(system_page, "seedDiagnosticCandidate", "local diagnostic fixture")
for privacy_flag in (
    "'candidateIdIncluded': false",
    "'thoughtBodyIncluded': false",
    "'messageBodyIncluded': false",
    "'outboundMessageIncluded': false",
):
    require(database, privacy_flag, f"privacy flag {privacy_flag}")
require(workflow, "validate_v0386_public_web_sharing.py", "workflow validator")

for forbidden in (
    "desire.feedThought(\n        text: claimed.title",
    "desire.feedThought(\n        text: claimed.summary",
    "desire.feedThought(\n        text: claimed.url",
):
    if forbidden in coordinator:
        raise SystemExit(f"untrusted web content crossed into Thought: {forbidden}")

print("v0.38.6 public web sharing closure validation passed")
