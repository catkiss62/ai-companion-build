#!/usr/bin/env python3
"""Lock the v0.42.2 media-transaction and freeze-copy repairs."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    controller = read("lib/features/chat/chat_controller.dart")
    provider = read("lib/core/diagnostics/provider_health.dart")
    telemetry = read("lib/core/diagnostics/attachment_pipeline_telemetry.dart")
    vision_copy = read("lib/core/diagnostics/vision_failure_presentation.dart")
    freeze_copy = read("lib/core/sync/transfer_freeze_presentation.dart")
    home = read("lib/features/home/companion_home_state.dart")
    relationship = read("lib/features/relationship/relationship_companion_state.dart")

    require("version: 0.42.2+246" in read("pubspec.yaml"), "version mismatch")
    require("_discardedImageMessageIds" in controller, "late vision result fence missing")
    require("_analyzingImageMessageId != message.id" in controller, "active image delete gate missing")
    require("outcome: discarded ? 'cancelled' : 'failed'" in controller, "deleted vision still records failure")
    require("_resumeUnfinishedVisionWhenIdle" in controller, "pending vision recovery missing")
    require("quota_exhausted" in provider, "free-quota category missing")
    require("free tier only" in provider, "free-tier-only evidence is not classified")
    require("RegExp(r'\\blease\\b')" in telemetry, "lease classifier still accepts substrings")
    require("免费额度已经用完" in vision_copy, "quota guidance missing")
    require("backup_export" in freeze_copy, "backup freeze purpose missing")
    require("她没有在换设备" in freeze_copy, "backup freeze still claims device transfer")
    require("freezePurpose" in home, "home freeze presentation is not purpose-aware")
    require("freezePurpose" in relationship, "relationship freeze presentation is not purpose-aware")

    print("v0.42.2 media transaction recovery contract passed")


if __name__ == "__main__":
    main()
