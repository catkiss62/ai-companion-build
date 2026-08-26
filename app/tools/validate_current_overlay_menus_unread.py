#!/usr/bin/env python3
"""Run a historical regression contract against the current release identity."""
from pathlib import Path
source = Path(__file__).with_name("validate_v0333_overlay_menus_unread.py").read_text(encoding="utf-8")
source = source.replace("0.34.6+71", "0.34.7+72")
source = source.replace("Build AI Companion v0.34.7+72 APK (Lock Resume)", "Build AI Companion v0.34.7+72 APK (Autonomous Action Foundation)")
source = source.replace("AI-Companion-v0.34.6-71-Lock-Resume-APK", "AI-Companion-v0.34.7-72-Autonomous-Action-Foundation-APK")
source = source.replace("python3 tools/validate_v0333_overlay_menus_unread.py", "python3 tools/validate_current_overlay_menus_unread.py")
# v0.38.18 merges edge docking into free mode. The historical menu token is
# replaced by the new migration contract for current-source validation.
source = source.replace(
    'optionButton(selectedLabel("贴边模式"',
    'private fun migrateLegacyMotionMode()',
)
# v0.35.9 moved unread increment to the single durable assistant commit owner.
# The native overlay now only acknowledges a completion while expanded, which
# prevents the former overlay send callback from double-incrementing the badge.
source = source.replace(
    "if (ok && !chatExpanded) setUnread(readUnread() + 1)",
    "if (ok && chatExpanded) setUnread(0)",
)
exec(compile(source, "validate_v0333_overlay_menus_unread.py", "exec"))
