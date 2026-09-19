#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def require(path: str, needles: list[str]) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    missing = [needle for needle in needles if needle not in text]
    if missing:
        raise SystemExit(f"{path}: missing {missing}")


policy = (ROOT / "lib/core/phone/simulated_phone_policy.dart").read_text(
    encoding="utf-8"
)
require(
    "lib/core/phone/simulated_phone_policy.dart",
    [
        "wishPresentationVersion = 3",
        "wishSubjectKeyForThought",
        "wishSubjectKey(",
        "key == DriveKey.curiosity",
        "旧记录没有保留具体主题",
        "自己的自主性会怎样慢慢长出来",
        "activity:garden_cat",
        "activity:leek",
        "shared.fishing.",
    ],
)
if "想认真弄明白最近惦记的那个问题" in policy:
    raise SystemExit("ambiguous current-wish fallback still exists")

require(
    "lib/core/phone/simulated_phone_repository.dart",
    [
        "'safe_subject_key'",
        "SimulatedPhonePolicy.wishSubjectKeyForThought",
        "Only its unsafe or no-longer-valid",
    ],
)
require(
    "test/simulated_phone_policy_v0388_test.dart",
    [
        "unknown curiosity topic is not projected without a safe subject",
        "safe self topic produces a concrete wish",
        "fishing detail aliases share one safe public subject",
        "legacy wish admits when its old record lost the concrete subject",
    ],
)

print("v0.41.89 wishlist safe-subject validation passed")
