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

assert "version: 0.38.4+103" in pubspec
assert "static const int schemaVersion = 32;" in database
assert "schemaVersion = 33" not in database

for token in (
    "static const double _metricLabelWidth = 72;",
    "static const double _metricValueWidth = 92;",
    "static const double _metricGap = 8;",
    "static const EdgeInsets _metricCardPadding = EdgeInsets.all(12);",
    "Widget _metricProgressRow({",
    "Widget _desireStateCard(BuildContext context, DesireSnapshot state)",
    "_desireStateCard(context, s)",
    "Widget _moeStateCard(BuildContext context)",
):
    assert token in inner, token

assert inner.count("padding: _metricCardPadding") == 2
assert inner.count("return _metricProgressRow(") == 2
assert inner.count("LinearProgressIndicator(") == 1
for token in (
    "fit: BoxFit.scaleDown",
    "maxLines: 1",
    "softWrap: false",
    "textAlign: TextAlign.end",
    "'欲望系统数值'",
    "'萌属性数值 · D2 数值引擎'",
    "'D3 表现：$d3Status'",
    "'调整 D3'",
    "PersonalityAppearancePage",
    "moe_expression_enabled",
):
    assert token in inner, token

for stale in (
    "SizedBox(width: 64, child: Text(drive.zhLabel))",
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
