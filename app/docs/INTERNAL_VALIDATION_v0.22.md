# AI Companion v0.22 · Internal Validation

## Scope

This checkpoint validates the software-only implementation of **Long-term Memory Consolidation / Conflict Semantics** on top of the verified v0.21 source baseline.

No APK was produced. The current environment has Java only and does not provide Flutter, Dart, Gradle or an Android SDK, so Flutter analyzer/tests, Gradle compilation and real-device behavior are intentionally not claimed.

## v0.22 memory checks

Executed `tools/validate_memory_v15_sql.py` successfully:

- v14 -> v15 additive memory migration preserves legacy rows.
- legacy shared experiences receive `shared_experience` semantics.
- confirmed current-fact replacement preserves the superseded historical row and increments fact version.
- low-confidence inference coexists without replacing the active current fact.
- unique evidence identity prevents durable retry from reinforcing twice.
- pinned current facts expose a deterministic automatic replacement block.
- manual restore detects an existing current fact for the same kind + subject and is blocked.
- migrated pre-v15 canonical text is preserved as `manual_edit_previous` evidence before a first manual rewrite.
- manual subject-key edit detects an existing current fact and is blocked.
- repeated full-state import remains idempotent with `memory_evidence`.

## Existing database/recovery regression suite

The following existing SQLite simulations were rerun and passed:

- `tools/validate_proactive_intent_sql.py`
- `tools/validate_durable_generation_sql.py`
- `tools/validate_async_worker_sql.py`
- `tools/validate_recovery_orchestration_sql.py`
- `tools/validate_reference_library_sql.py`
- `tools/validate_companion_home_sql.py`
- `tools/validate_awareness_sql.py`
- `tools/validate_relationship_presentation_sql.py`

This covers proactive intent/history, durable generation ownership, stale run-token fencing and exactly-once behavior, Recovery Orchestrator boundaries, Reference transactional consistency, Companion Home read models, awareness migration/dedupe/expiry/Active-Brain behavior, and relationship-presentation Thought filtering.

## Static/source validation

Executed `tools/validate_v022.py --baseline-zip /mnt/data/ai_companion_v0_21_source.zip` successfully.

Validated:

- Android Manifest/XML structure.
- Dart relative imports.
- Dart/Kotlin delimiter balance.
- duplicate Dart declarations.
- app version/schema contract (`0.22.0+22`, schema v15).
- v15 MemoryItem semantic/evidence/version fields.
- current/inference/shared/history conflict rules.
- bounded retrieval and prompt labels.
- memory UI semantic/evidence presentation.
- proactive pipeline and notification quick reply regressions.
- Companion Home, Reference, Perception Context, Relationship presentation and true-overlay source regressions.

## Baseline freeze

Using the supplied verified v0.21 source ZIP as the byte baseline:

- **222** old files outside the explicit v0.22 allowlist were SHA-256 byte-identical.
- **41** TTS-critical files were SHA-256 byte-identical: **0 changed / 0 missing**.

This confirms v0.22 did not silently alter unrelated stable subsystems or the frozen TTS chain.

## Not validated in this environment

- Flutter analyzer.
- Dart/Flutter runtime tests.
- Gradle/Android APK compilation.
- Android database migration on physical device storage.
- small-screen / large-font memory evidence UI.
- phone↔tablet real-device state transfer.
- months-scale subjective memory extraction quality.

Those remain explicit future checkpoints rather than inferred pass results.
