#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise SystemExit(f"missing {label}: {needle}")


pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
policy = read("lib/core/autonomy/public_web_discovery_policy.dart")
provider = read("lib/core/autonomy/wikimedia_public_web_provider.dart")
engine = read("lib/core/autonomy/public_web_discovery_engine.dart")
coordinator = read("lib/core/autonomy/autonomous_action_coordinator.dart")
proactive = read("lib/core/desire/proactive_engine.dart")
desire_policy = read("lib/core/desire/desire_core_policy.dart")
diagnostics = read("lib/core/diagnostics/preflight_diagnostics.dart")
policy_tests = read("test/public_web_discovery_policy_v0348_test.dart")
provider_tests = read("test/wikimedia_public_web_provider_v0348_test.dart")
workflow = read("../.github/workflows/build-apk.yml")

require(pubspec, "version: 0.34.8+73", "release version")
require(database, "static const int schemaVersion = 25;", "schema v25")
require(database, "if (oldVersion < 25)", "schema v25 migration")
require(database, "CREATE TABLE IF NOT EXISTS public_web_candidates", "candidate pool")
for column in (
    "fingerprint TEXT NOT NULL UNIQUE",
    "safety_state TEXT NOT NULL DEFAULT 'untrusted_public'",
    "lifecycle_state TEXT NOT NULL DEFAULT 'unread'",
    "action_run_id TEXT NOT NULL",
    "expires_at INTEGER NOT NULL",
):
    require(database, column, f"candidate column {column}")
for setting in (
    "public_web_discovery_enabled",
    "last_public_web_discovery_at",
    "last_public_web_discovery_success_at",
    "last_public_web_discovery_outcome",
    "last_public_web_discovery_error",
):
    require(database, setting, f"runtime setting {setting}")

require(engine, "desire.previewCandidates", "existing Desire intent source")
require(engine, "PublicWebDiscoveryPolicy.toToolIntent", "Desire route intent")
require(engine, "coordinator.requestFromDesire", "Tool Gate")
require(engine, "coordinator.claim", "durable claim")
require(engine, "completeWithoutSatisfaction", "failure without satisfaction")
require(engine, "completePublicWebSuccess", "candidate success transaction")
require(engine, "cancelled_before_commit", "generation-race run closure")
require(engine, "never sends a", "separate proactive delivery boundary")
require(proactive, "publicWebDiscovery.maybeDiscover", "heartbeat schedule")
require(proactive, "final snapshot = await db.loadDesire();", "post-discovery reload")

for drive in ("DriveKey.curiosity", "DriveKey.reflection", "DriveKey.social"):
    require(policy, drive, f"safe topic drive {drive}")
require(policy, "static const dailyLimit = 4;", "rolling daily limit")
require(policy, "Duration(hours: 24)", "rolling budget window")
require(policy, "Duration(days: 14)", "candidate TTL")
require(policy, "static const candidateCap = 240;", "candidate cap")
require(policy, "wantAction: 'discover_interest'", "route action")
require(policy, "final sixHourBucket", "six-hour dedupe topic bucket")
require(provider, "zh.wikipedia.org", "official Wikimedia domain")
require(provider, "'/w/rest.php/v1/search/page'", "official REST search endpoint")
require(provider, "'limit': '5'", "bounded provider result request")
require(provider, "timeout(const Duration(seconds: 12))", "network timeout")
require(provider, "if (candidates.length >= 3) break", "per-run candidate cap")
require(provider, "safetyState", "untrusted candidate state")

require(database, "Future<int> completePublicWebDiscovery", "atomic candidate commit")
require(database, "recoverStaleAutonomousActions", "stale action recovery")
require(database, "Duration(minutes: 5)", "bounded stale action lease")
require(database, "'succeeded', 'no_result', 'failed'", "same-window terminal dedupe")
require(database, "generation_jobs WHERE status IN", "completion generation fence")
require(database, "id = ? AND status = ? AND run_token = ? AND tool_kind = ?", "run token fence")
require(database, "satisfyOnSuccess(current)", "success-only Desire satisfaction")
require(database, "LIMIT 240", "database cap")
require(coordinator, "intensity: 0.24", "small Desire satisfaction")
require(desire_policy, "case 'discover_interest':", "Desire settlement mapping")

require(diagnostics, "'publicWebCandidates': publicWebCandidates", "candidate diagnostics")
for marker in (
    "publicWebCandidateTitleIncluded",
    "publicWebCandidateSummaryIncluded",
    "publicWebCandidateUrlIncluded",
    "publicWebQueryOrInterestKeyIncluded",
):
    require(diagnostics, marker, f"privacy marker {marker}")
require(database, "'titleIncluded': false", "candidate title redaction")
require(database, "'summaryIncluded': false", "candidate summary redaction")
require(database, "'urlIncluded': false", "candidate URL redaction")
require(database, "'queryIncluded': false", "query redaction")
require(database, "'interestKeyIncluded': false", "interest-key redaction")

require(policy_tests, "query comes from a fixed public list", "fixed-topic privacy test")
require(policy_tests, "dedupe changes only at a six-hour UTC boundary", "dedupe test")
require(provider_tests, "parses at most three metadata candidates", "parser cap test")
require(provider_tests, "title and summary storage are bounded", "payload bounds test")

require(workflow, "Build AI Companion v0.34.8+73 APK", "workflow title")
require(workflow, "python3 tools/validate_v0348_public_web_discovery.py", "validator invocation")
require(workflow, "AI-Companion-v0.34.8-73-Public-Web-Discovery-APK.apk", "APK identity")
require(workflow, "Draft Release upload attempt", "release upload retry")

print("v0.34.8 public web discovery validation passed")
