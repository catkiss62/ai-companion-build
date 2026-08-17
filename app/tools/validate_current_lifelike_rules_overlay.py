#!/usr/bin/env python3
"""Run the v0.34.3 regression contract against the current release identity."""
from pathlib import Path
source = Path(__file__).with_name("validate_v0343_lifelike_rules_overlay.py").read_text(encoding="utf-8")
source = source.replace("0.34.6+71", "0.34.7+72")
source = source.replace("Build AI Companion v0.34.7+72 APK (Lock Resume)", "Build AI Companion v0.34.7+72 APK (Autonomous Action Foundation)")
source = source.replace("AI-Companion-v0.34.6-71-Lock-Resume-APK", "AI-Companion-v0.34.7-72-Autonomous-Action-Foundation-APK")
source = source.replace("python3 tools/validate_v0343_lifelike_rules_overlay.py", "python3 tools/validate_current_lifelike_rules_overlay.py")
exec(compile(source, "validate_v0343_lifelike_rules_overlay.py", "exec"))
