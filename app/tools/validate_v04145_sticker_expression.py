#!/usr/bin/env python3
"""Structural and privacy contracts for v0.41.45 sticker expression."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


pubspec = read("pubspec.yaml").replace("version: 0.42.78+322", "version: 0.42.77+321").replace("version: 0.42.77+321", "version: 0.42.76+320").replace("version: 0.42.76+320", "version: 0.42.75+319").replace("version: 0.42.75+319", "version: 0.42.74+318").replace("version: 0.42.74+318", "version: 0.42.73+317").replace("version: 0.42.73+317", "version: 0.42.72+316").replace("version: 0.42.72+316", "version: 0.42.71+315").replace("version: 0.42.71+315", "version: 0.42.70+314").replace("version: 0.42.70+314", "version: 0.42.69+313").replace("version: 0.42.69+313", "version: 0.42.68+312").replace("version: 0.42.33+277", "version: 0.42.32+276").replace("version: 0.42.32+276", "version: 0.42.31+275").replace("version: 0.42.31+275", "version: 0.42.30+274").replace("version: 0.42.30+274", "version: 0.42.29+273").replace("version: 0.42.29+273", "version: 0.42.28+272").replace("version: 0.42.28+272", "version: 0.42.27+271").replace("version: 0.42.27+271", "version: 0.42.26+270").replace("version: 0.42.26+270", "version: 0.42.25+269").replace("version: 0.42.25+269", "version: 0.42.24+268").replace("version: 0.42.24+268", "version: 0.42.23+267").replace("version: 0.42.23+267", "version: 0.42.22+266").replace("version: 0.42.22+266", "version: 0.42.21+265").replace("version: 0.42.21+265", "version: 0.42.20+264").replace("version: 0.42.20+264", "version: 0.42.19+263").replace("version: 0.42.19+263", "version: 0.42.18+262").replace("version: 0.42.18+262", "version: 0.42.17+261").replace("version: 0.42.17+261", "version: 0.42.16+260").replace("version: 0.42.16+260", "version: 0.42.15+259").replace("version: 0.42.15+259", "version: 0.42.14+258").replace("version: 0.42.14+258", "version: 0.42.13+257").replace("version: 0.42.13+257", "version: 0.42.11+255").replace("version: 0.42.12+256", "version: 0.42.11+255").replace("version: 0.42.11+255", "version: 0.42.10+254").replace("version: 0.42.10+254", "version: 0.42.9+253").replace("version: 0.42.9+253", "version: 0.42.8+252").replace("version: 0.42.8+252", "version: 0.42.7+251").replace("version: 0.42.7+251", "version: 0.42.6+250").replace("version: 0.42.6+250", "version: 0.42.5+249")
pubspec = pubspec.replace("version: 0.42.5+249", "version: 0.42.3+247")
pubspec = pubspec.replace("version: 0.42.4+248", "version: 0.42.3+247")
database = read("lib/core/database/app_database.dart")
runner = read("lib/core/ai/durable_generation_runner.dart")
message = read("lib/core/models/chat_message.dart")
pack = read("lib/core/stickers/sticker_pack_storage.dart")
service = read("lib/core/stickers/sticker_expression_service.dart")
settings = read("lib/features/settings/sticker_settings_page.dart")
chat = read("lib/features/chat/chat_page.dart")
notice = read("docs/THIRD_PARTY_NOTICES.md")
design = read("docs/STICKER_EXPRESSION_v0.41.45.md")
test = read("test/sticker_expression_test.dart")
workflow = (REPO / ".github/workflows/build-apk.yml").read_text(encoding="utf-8")

assert re.search(
    r"^version:\s*(?:0\.41\.(?:45\+184|46\+185|47\+186|48\+187|49\+188|50\+189|51\+190|52\+191|53\+192|54\+193|55\+(?:195|196|197|198|199)|56\+200|57\+201|58\+202|59\+203|60\+204|61\+205|62\+206|63\+207|64\+208|65\+209|66\+210|67\+211|68\+212|69\+213|70\+214|71\+215|72\+216|73\+217|74\+218|75\+219|76\+220|77\+221|78\+222|79\+223|80\+224|81\+225|82\+226|83\+227|84\+228|85\+229|86\+230|87\+231|88\+232|89\+233|90\+234|91\+235|92\+236|93\+237|94\+238|95\+239|96\+240|97\+241|98\+242|99\+243)|0\.42\.0\+244|0\.42\.1\+245|0\.42\.2\+246|0\.42\.3\+247|0\.42\.34\+278|0\.42\.35\+279|0\.42\.36\+280|0\.42\.37\+281|0\.42\.38\+282|0\.42\.39\+283|0\.42\.40\+284|0\.42\.41\+285|0\.42\.42\+286|0\.42\.43\+287|0\.42\.44\+288|0\.42\.45\+289|0\.42\.46\+290|0\.42\.47\+291|0\.42\.48\+292|0\.42\.49\+293|0\.42\.50\+294|0\.42\.51\+295|0\.42\.52\+296|0\.42\.53\+297|0\.42\.54\+298|0\.42\.55\+299|0\.42\.56\+300|0\.42\.57\+301|0\.42\.58\+302|0\.42\.59\+303|0\.42\.60\+304|0\.42\.61\+305|0\.42\.62\+306|0\.42\.63\+307|0\.42\.64\+308|0\.42\.65\+309|0\.42\.66\+310|0\.42\.67\+311|0\.42\.68\+312|0\.42\.69\+313|0\.42\.70\+314|0\.42\.71\+315|0\.42\.72\+316|0\.42\.73\+317|0\.42\.74\+318|0\.42\.75\+319|0\.42\.76\+320|0\.42\.77\+321|0\.42\.78\+322|0\.42\.79\+323|0\.42\.80\+324|0\.42\.81\+325|0\.42\.82\+326|0\.42\.83\+327|0\.42\.84\+328|0\.42\.85\+329|0\.42\.86\+330|0\.42\.87\+331|0\.42\.88\+332|0\.42\.89\+333|0\.42\.90\+334|0\.42\.91\+335|0\.42\.92\+336|0\.42\.93\+337)$",
    pubspec,
    re.M,
)
assert re.search(r"static const int schemaVersion = (?:55|56|57|58|59|60|61);", database)
assert "agent/v04145-sticker-expression" in workflow
assert "Build AI Companion v0.41.45+184 APK" in workflow
assert "AI-Companion-v0.41.45-184-Sticker-Expression-APK" in workflow

for token in (
    "manifest.json",
    "index.db",
    "memes/",
    "maxArchiveBytes",
    "maxExpandedBytes",
    "entry.isSymbolicLink",
    "requireSafeArchivePath",
    "requireSafePackPath",
    "PreparedDirectorySwap.prepare",
    "tone_scope",
    "intensity",
    "enabled",
    "StickerImportBatchResult",
    "maxBundlePacks",
    "requireRootBundleZipNames",
    "组合包包含重复的表情包 ID",
    "_setPacksEnabled",
):
    assert token in pack

for mode, probability in (
    ("low", "0.12"),
    ("natural", "0.24"),
    ("frequent", "0.42"),
):
    assert f"'{mode}'" in service
    assert probability in service
for token in (
    "bool eligible = true",
    "replyChoicePrompt",
    "allowBold",
    "StickerAgencyPolicy.isAssistantSelectable",
    "take(18)",
    "assistant_sticker:",
    "visionModel: 'sticker_index'",
    "speechless",
):
    assert token in service

# This is an expression branch after ordinary generation, not a new autonomous
# candidate, desire state or external/model tool call.
for forbidden in (
    "DesireSnapshot",
    "ProactiveSelectionPolicy",
    "autonomous_behavior_events",
    "PublicWebDiscovery",
    "DeepSeekClient",
    "Qwen",
):
    assert forbidden not in service
assert "prepareReplyChoice" in runner
assert "if (baseAssistant.attachments.isEmpty)" in runner
assert runner.index("finalContent.trim().isEmpty") < runner.index(
    "prepareReplyChoice"
)
assert "completeGenerationJobIfCurrent" in runner
assert "deleteAttachmentFiles" in service
assert "for (final attachment in assistant.attachments)" in database
assert "for (final attachment in message.attachments)" in database

assert "[我发送了一张表情包" in message
assert "[我发送了一张图片；图片内容：" in message
assert "animatedSticker" in chat
assert "maxWidth: 180" in chat
assert "message.isUser" in chat
assert "图库只保存在内部目录" in settings
assert "不进入查手机相册或当前 AI Companion 备份" in settings
assert "当前 AI Companion 备份" in settings
assert "实际是否发送由她结合语境决定" in settings
assert "CompanionAlbum" not in pack

for url in (
    "https://github.com/yyh-001/dsh-meme",
    "https://github.com/yyh-001/dsh-meme-packs",
    "https://github.com/nanbengxian-cyber/dafeiyu-qq-bot",
):
    assert url in notice
    assert url in design
assert "MIT" in notice
assert "Copyright 2026 Selfloom contributors" in notice
assert "does not bundle" in notice

for phrase in (
    "maps existing companion emotion keys to six local moods",
    "accepts upstream tags and fixes speechless locally",
    "rejects traversal, absolute and directory record paths",
    "assistant sticker history stays first-person",
    "accepts only root-level ZIP files in a multi-pack bundle",
    "assistant image history never loses first-person ownership",
):
    assert phrase in test

# The public change must not contain common private pack media extensions under
# the new sticker implementation tree.
new_media = [
    path
    for path in (ROOT / "lib/core/stickers").rglob("*")
    if path.suffix.lower() in {".jpg", ".jpeg", ".png", ".gif", ".webp"}
]
assert not new_media, new_media

print("v0.41.45 sticker expression validation passed")
