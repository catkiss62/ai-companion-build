#!/usr/bin/env python3
"""Static source contract for v0.41.39 public-web reading and narrow fixes."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DB = (ROOT / "lib/core/database/app_database.dart").read_text(encoding="utf-8")
PROVIDER = (ROOT / "lib/core/autonomy/layered_public_web_provider.dart").read_text(encoding="utf-8")
APPRAISER = (ROOT / "lib/core/autonomy/public_web_deepseek_appraiser.dart").read_text(encoding="utf-8")
DISCOVERY = (ROOT / "lib/core/autonomy/public_web_discovery_engine.dart").read_text(encoding="utf-8")
SHARE = (ROOT / "lib/core/autonomy/public_web_share_coordinator.dart").read_text(encoding="utf-8")
PROMPT = (ROOT / "lib/core/ai/prompt_builder.dart").read_text(encoding="utf-8")
REFERENCE = (ROOT / "lib/core/reference/reference_library.dart").read_text(encoding="utf-8")
VISION = (ROOT / "lib/core/ai/qwen_vision_client.dart").read_text(encoding="utf-8")
ALBUM = (ROOT / "lib/core/phone/companion_album_discovery_engine.dart").read_text(encoding="utf-8")
PLANNER = (ROOT / "lib/core/agent/agent_tool_planner.dart").read_text(encoding="utf-8")
PHONE = (ROOT / "lib/features/phone/simulated_phone_page.dart").read_text(encoding="utf-8")
PHONE_READER = (ROOT / "lib/core/phone/simulated_phone_reader.dart").read_text(encoding="utf-8")
PUBSPEC = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")


def require(source: str, token: str, label: str) -> None:
    assert token in source, f"missing {label}: {token}"


require(PUBSPEC, "version: 0.41.39+178", "build identity")
require(DB, "static const int schemaVersion = 51;", "schema identity")
for token in (
    "_createV51PublicWebReadingColumns",
    "_stabilizeV51PublicWebReading",
    "legacy_unverified",
    "public_web_knowledge",
    "deleteCompanionBrowserVisit",
    "user_deleted",
    "last_acted_at IS NULL",
    "activePublicWebKnowledgeContext",
    "search_query",
):
    require(DB, token, f"schema/lifecycle contract {token}")

for token in (
    "Uri.https('api.tavily.com', '/search')",
    "Uri.https('api.tavily.com', '/extract')",
    "raw_content",
    "summarizeExtracted",
    "reader_summary",
    "key_points",
    "uncertainties",
    "topic_tags",
    "_chunks(content, 28000)",
    "pageReadingEnabled",
):
    require(PROVIDER, token, f"complete-reading contract {token}")

for token in (
    "DeepSeekPublicWebAppraiser",
    "semantic_state",
    "interest_score",
    "learning_score",
    "share_score",
    "history_only",
):
    require(APPRAISER, token, f"main-model appraisal {token}")
require(DISCOVERY, "adaptiveDailyLimit", "adaptive eight-credit ceiling")
require(DISCOVERY, "defaultDailyLimit", "default six-credit budget")
require(SHARE, "rereadCandidate", "share-time source refresh")
require(SHARE, "completePublicWebShareRefresh", "share refresh persistence")
require(SHARE, "context: 'share_refresh'", "share refresh provider telemetry")

require(PROMPT, "VERIFIED_WEB_KNOWLEDGE", "sourced knowledge prompt lane")
require(PROMPT, "角色扮演执行锚点 · 当前 Session 有效", "late roleplay anchor")
require(PROMPT, "场景中的“我”就是该角色", "scene identity execution")
require(REFERENCE, "当前正在角色扮演", "explicit roleplay mode cue")
require(REFERENCE, "不得用 AI 本体身份否认", "roleplay identity priority")

require(VISION, "requestedSubject", "pixel request input")
require(VISION, "request_match", "pixel semantic result")
require(VISION, "纯站点标识", "site-mark mismatch rule")
require(ALBUM, "requestMatches", "local semantic gate")
require(ALBUM, "request_mismatch", "truthful mismatch outcome")
require(PLANNER, "存一张", "natural image-save route")
require(PHONE, "删除这条浏览记录", "manual browser deletion")
require(PHONE, "旧版搜索片段 · 未重新读取原网页", "legacy browser label")
require(PHONE, "原网页读取时间：", "browser read time display")
require(PHONE, "搜索：", "browser search query display")
require(PHONE, "保存时间：", "album time display")
require(PHONE_READER, "item.searchQuery", "agent-visible browser search query")
require(PHONE_READER, "item.readAt", "agent-visible browser read time")

schema51 = DB[
    DB.index("Future<void> _createV51PublicWebReadingColumns"):
    DB.index("Future<void> _stabilizeV51PublicWebReading")
]
assert "raw_content" not in schema51, "raw webpage bodies must not be persisted"
assert "page_body" not in schema51, "raw webpage bodies must not be persisted"
assert "ai_interest" not in schema51, (
    "schema 51 must not activate mature AI interest"
)

extract_method = PROVIDER[
    PROVIDER.index("Future<_TavilyExtractBatch> _extract"):
    PROVIDER.index("Future<_TavilyBatch> _search")
]
assert "'query':" not in extract_method, (
    "Tavily Extract must omit query so it returns the complete cleaned page body"
)

print("v0.41.39 public-web reading and narrow-fix source contract validated")
