from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUNNER = (ROOT / "lib/core/ai/durable_generation_runner.dart").read_text()
PROMPT = (ROOT / "lib/core/ai/prompt_builder.dart").read_text()
INITIATIVE = (
    ROOT / "lib/core/desire/conversation_initiative_policy.dart"
).read_text()
OUTCOME = (ROOT / "lib/core/desire/ordinary_desire_response.dart").read_text()
EXTRACTOR = (ROOT / "lib/core/ai/memory_extractor.dart").read_text()
DB = (ROOT / "lib/core/database/app_database.dart").read_text()
SETTINGS = (ROOT / "lib/features/settings/settings_page.dart").read_text()
PROACTIVE = (ROOT / "lib/core/desire/proactive_engine.dart").read_text()
REPORT = (ROOT / "lib/core/diagnostics/preflight_diagnostics.dart").read_text()
TELEMETRY = (
    ROOT / "lib/core/diagnostics/conversation_initiative_telemetry.dart"
).read_text()
PUBSPEC = (ROOT / "pubspec.yaml").read_text()
WORKFLOW = (ROOT.parent / ".github/workflows/build-apk.yml").read_text()


def require(text: str, token: str, label: str) -> None:
    assert token in text, f"missing {label}: {token}"


require(PUBSPEC, "version: 0.40.4+133", "version")
require(DB, "static const int schemaVersion = 40;", "schema stays 40")

assert "desireEngine.satisfy(DriveKey.attachment" not in RUNNER
require(EXTRACTOR, "ordinary_desire_response", "semantic response contract")
require(EXTRACTOR, "OrdinaryDesireResponseOutcome.parse", "outcome parser")
require(DB, "applyPostTurnDesirePulsesOnce", "idempotent desire write")
require(DB, "satisfactionIntensity", "result-based satisfaction")
require(OUTCOME, "'engaged'", "engaged outcome")
require(OUTCOME, "'acknowledged'", "acknowledged outcome")
for outcome in ("deferred", "dodged", "refused", "redirected"):
    require(OUTCOME, f"'{outcome}'", f"{outcome} outcome")

for mode in (
    "stayWithUserTopic",
    "probeUserTopic",
    "shareOwnView",
    "openOwnTopic",
    "seekAttention",
    "inviteSharedActivity",
    "flirtOrInsist",
    "showOwnNeed",
):
    require(INITIATIVE, mode, f"initiative mode {mode}")
require(INITIATIVE, "继续用户话题不等于被动", "topic-continuation boundary")
require(INITIATIVE, "绝不根据用户消息的字数", "no length inference")
require(INITIATIVE, "不自动占据成熟姐姐", "girlfriend posture")
require(INITIATIVE, "禁止随机争吵", "anti-random-conflict guard")
require(PROMPT, "conversationInitiative.promptSection()", "prompt integration")

require(DB, "beginFreshConversationContext", "safe context reset")
require(DB, "conversation_context_reset_at", "context boundary")
require(DB, "conversation_context_reset_count", "reset audit counter")
require(DB, "recentMessagesForPrompt", "prompt-only recent history")
require(DB, "status IN ('pending','running','retry_wait')", "active job refusal")
require(DB, "g.status = 'failed'", "failed turn refusal")
require(DB, "'interaction_sessions'", "session ending")
require(RUNNER, "notBefore: await db.conversationContextResetAt()", "user prompt cutoff")
require(PROACTIVE, "recentMessagesForPrompt", "proactive prompt cutoff")
require(SETTINGS, "开始新的对话上下文", "settings action")
require(SETTINGS, "聊天记录、长期记忆、关系进度", "non-destructive explanation")
require(PROMPT, "FRESH CONVERSATION CONTEXT", "fresh prompt marker")

require(REPORT, "'conversationInitiative': conversationInitiative", "diagnostic section")
require(TELEMETRY, "'messageLengthUsedForDisengagement': false", "length privacy flag")
for token in (
    "'promptBodiesIncluded': false",
    "'messageBodiesIncluded': false",
    "'thoughtBodiesIncluded': false",
    "'memoryBodiesIncluded': false",
    "'messageIdsIncluded': false",
    "'topicKeysIncluded': false",
    "'rawModelJsonIncluded': false",
):
    require(TELEMETRY, token, "diagnostic privacy")

require(
    WORKFLOW,
    "name: Build AI Companion v0.40.4+133 APK (Desire Conversation Agency)",
    "workflow name",
)
require(WORKFLOW, "agent/v0404-desire-conversation-agency", "workflow branch")
require(
    WORKFLOW,
    "AI-Companion-v0.40.4-133-Desire-Conversation-Agency-APK",
    "workflow artifact",
)
require(
    WORKFLOW,
    "python3 tools/validate_v0404_desire_conversation_agency.py",
    "workflow validator",
)

print("v0.40.4 desire conversation agency validation passed")
