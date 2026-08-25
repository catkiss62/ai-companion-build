#!/usr/bin/env python3
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


grouping = read("lib/core/rules/rule_layer_grouping.dart")
service = read("lib/core/rules/rule_layer_service.dart")
page = read("lib/features/settings/rule_layers_page.dart")
tests = read("test/rule_layer_defaults_test.dart")
pubspec = read("pubspec.yaml")

version = re.search(
    r"^version: (\d+)\.(\d+)\.(\d+)\+(\d+)$",
    pubspec,
    re.MULTILINE,
)
assert version is not None
assert tuple(map(int, version.groups())) >= (0, 31, 6, 48)

for key in (
    "01_core",
    "01_relationship",
    "02_daily",
    "03_behavior",
    "03_personality_seed",
    "03_appearance_identity",
    "04_intimacy_core",
    "05_intimacy_rendering",
    "06_intimacy_reference",
):
    assert key in grouping, key

assert "'01_relationship': '01'" in grouping
assert "'03_personality_seed': '03'" in grouping
assert "'03_appearance_identity': '01'" in grouping
assert "'03_behavior': '02'" in grouping
assert "'04_memory_rules': '04'" in grouping
assert "List<RuleLayer>.unmodifiable" in grouping
assert "groupRuleLayers(layers)" in service
assert "ruleLayerSectionTitle(layer)" in service
assert "groupRuleLayers(layers)" in page
assert "db.updateRuleLayer(" in page
assert "db.resetRuleLayer(layer.key)" in page
assert "without concatenating their storage" in tests

print("v0.31.6 rule grouping validation passed")
