#!/usr/bin/env python3
"""Static contracts for v0.41.11 isolated personality-learning review."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "app"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


pubspec = read(APP / "pubspec.yaml")
models = read(APP / "lib/core/models/personality_learning.dart")
extractor = read(APP / "lib/core/ai/memory_extractor.dart")
database = read(APP / "lib/core/database/app_database.dart")
diagnostics = read(APP / "lib/core/diagnostics/preflight_diagnostics.dart")
tests = read(APP / "test/personality_learning_phase1_test.dart")
docs = read(APP / "docs/PERSONALITY_LEARNING_GROWTH_PHASE1.md")
ledger = read(ROOT / "AI_Companion_当前总账.md")
workflow = read(ROOT / ".github/workflows/build-apk.yml")

assert any(
    version in pubspec
    for version in (
        "version: 0.41.11+150",
        "version: 0.41.12+151",
        "version: 0.41.13+152", "version: 0.41.14+153",
        "version: 0.41.17+156",
    )
)
assert "static const int schemaVersion = 42;" in database

for token in (
    "semanticReviewUnrelated('semantic_review_unrelated')",
    "semanticReviewAmbiguous('semantic_review_ambiguous')",
    "semanticReviewUnavailable('semantic_review_unavailable')",
    "PersonalityLearningParseResult.reviewRequired",
    "semanticReviewApprovedTargetId",
    "PersonalityLearningSemanticReviewRequest",
    "normalizedUser.length < 12",
    "_isContextOnlyPacingReply(normalizedUser)",
    "PersonalityLearningEvidenceKind.revealedChoice",
):
    assert token in models, token
assert "const PersonalityLearningParseResult.reviewRequired" not in models

for token in (
    "人格学习证据的隔离语义复核器",
    "'current_user_message': userText",
    "'evidence_quote': request.evidenceQuote",
    "'target_proposition': request.target.proposition",
    "'support', 'contradict', 'unrelated', 'ambiguous'",
    "if (confidence < 0.86) relation = 'ambiguous'",
    "personality_learning_semantic_reviews",
    "checkpointPostTurnProposal",
    "semanticReviewApprovedTargetId: reviewRequest.target.id",
):
    assert token in extractor, token

# The isolated verifier payload must not receive either assistant message.
review_start = extractor.index("你是人格学习证据的隔离语义复核器")
review_end = extractor.index("await _recordPersonalityLearningSemanticReview", review_start)
review_block = extractor[review_start:review_end]
assert "assistant.content" not in review_block
assert "previousAssistant" not in review_block
assert "memoryCandidateContext" not in review_block
assert "learningCandidateContext" not in review_block

for token in (
    "semanticReviewCounts",
    "lastSemanticReviewAt",
    "lastSemanticReviewOutcome",
    "semanticReviewBodiesIncluded': false",
):
    assert token in database, token
assert "personalityLearningSemanticReviewBodiesIncluded': false" in diagnostics

for token in (
    "natural synonym support requests isolated semantic review",
    "偶尔斗嘴，经常互相对骂",
    "same-subject target omission can only rejoin after semantic review",
    "explicit unrelated preference cannot pass without semantic review",
    "short explicit unrelated preference is rejected before API review",
    "short agreement never reaches isolated semantic review",
    "嗯嗯，没错！嘿嘿",
    "true-device pacing reply cannot borrow the AI context target",
):
    assert token in tests, token

for token in (
    "v0.41.11",
    "隔离语义复核",
    "误判不可接受",
    "Phase 1",
):
    assert token in docs or token in ledger, token

for token in (
    "Build AI Companion v0.41.11+150 APK (Personality Learning Semantic Verifier)",
    "AI-Companion-v0.41.11-150-Personality-Learning-Semantic-Verifier-APK",
    "v0.41.11-personality-learning-semantic-verifier-test",
    "validate_v04111_personality_learning_semantic_verifier.py",
):
    assert token in workflow, token

print("v0.41.11 personality learning semantic verifier validation passed")
