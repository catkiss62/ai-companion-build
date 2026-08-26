#!/usr/bin/env python3
"""Validate v0.38.4 inner-page metric geometry and D2/D3 visibility."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    value = (ROOT / path).read_text(encoding="utf-8")
    assert value.strip(), path
    return value


pubspec = read("pubspec.yaml")
database = read("lib/core/database/app_database.dart")
inner = read("lib/features/inner/inner_page.dart")
workflow = read("../.github/workflows/build-apk.yml")

assert any(
    version in pubspec
    for version in ("version: 0.38.4+103", "version: 0.38.5+104", "version: 0.38.6+105", "version: 0.38.7+106")
)
assert (\n    "static const int schemaVersion = 32;" in database\n    or "static const int schemaVersion = 33;" in database\n)

for token in (
    "Widget _desireProgressRow({",
    "padding: const EdgeInsets.symmetric(vertical: 5)",
    "SizedBox(width: 64, child: Text(label))",
    "Widget _moeProgressRow({",
    "padding: const EdgeInsets.symmetric(vertical: 4)",
    "SizedBox(width: 72, child: Text(label))",
    "fit: BoxFit.scaleDown",
    "maxLines: 1",
    "softWrap: false",
    "textAlign: TextAlign.end",
    "'萌属性数值 · D2 数值引擎'",
    "'D3 表现：$d3Status'",
    "'调整 D3'",
    "PersonalityAppearancePage",
    "moe_expression_enabled",
):
    assert token in inner, token

assert inner.count("Widget _desireProgressRow({") == 1
assert inner.count("Widget _moeProgressRow({") == 1
assert inner.count("LinearProgressIndicator(") == 2
for stale in (
    "Widget _metricProgressRow({",
    "Widget _desireStateCard(",
    "SizedBox(width: 74",
    "萌属性数值 · D2 影子模式",
):
    assert stale not in inner, stale

for token in (
    "Build AI Companion v0.38.4+103 APK",
    "validate_v0384_inner_metric_layout.py",
    "AI-Companion-v0.38.4-103-Inner-Metric-Layout-APK",
    "v0.38.4-inner-metric-layout-test",
    ".ci/v0384-monitor.txt",
):
    assert token in workflow, token

print("v0.38.4 inner metric layout and D2/D3 visibility validation passed")
