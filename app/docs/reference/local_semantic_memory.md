# Local semantic memory (v0.42.189 candidate)

This is a retrieval-layer addition, not a replacement for memory extraction,
source evidence, revision handling, historical recall or the existing archive.
No cloud embeddings or reranking calls are made.

## Reproducible model

- Upstream: https://huggingface.co/BAAI/bge-small-zh-v1.5 (MIT)
- ONNX conversion: https://huggingface.co/Xenova/bge-small-zh-v1.5
- Pinned revision: `75c43b069aac4d136ba6bc1122f995fedcfd2781`.
- Quantized model: 24,010,842 bytes, SHA256
  `15b717c382bcb518ba457b93ea6850ede7f4f1cd8937454aa06972366cd19bcc`.
- Tokenizer SHA256: `48cea5d44424912a6fd1ea647bf4fe50b55ab8b1e5879c3275f80e339e8fae26`.
- Run `python app/tools/prepare_memory_embedding.py` before a local APK build.
  CI does this automatically. Both files are packaged offline, not downloaded on
  the user's phone. Only the hash-verified model and tokenizer are fetched.
- Existing ONNX Runtime Android 1.22.0 dependency is reused; CPU, one intra/inter
  op thread. Do not close the global ORT environment shared with Genie TTS.
- Case-sensitive BERT WordPiece, max 512 tokens with CLS/SEP, mean pooling over
  real tokens including special tokens, L2 normalization, 512 dimensions.
  This follows memory-keeper's mean pooling, not an accidental CLS-pooling mix.

## Retrieval and cache

Active, source-valid, admitted current facts and shared experiences are eligible.
The source table is authoritative every lookup, including after archive restore.
Cache keys are hashes of content + tags, independent of mutable recall timestamps.
Changed content gets a new key. Deleted, retired and replaced rows cannot enter
results from old vectors. Cache is disposable app-cache data, outside archives.
Model/tokenizer/pooling identity namespaces it. A partial old archive index is
not used until the currently eligible rows are covered. Index batches run on the
native worker with yields; lexical recall continues during indexing/failure.

Semantic top 40 and lexical ranking are fused using reciprocal ranks. Initial
semantic floor 0.50 and relative window 0.15 are heuristic admission parameters,
not confidence probabilities. They need real-device and user-memory evaluation.
Same-topic associations can compete for final slots. User-turn retrieval does not
cool down simply because an item was recently injected; proactive cooldowns remain.

Diagnostics expose model identity, status, indexed and pending counts. The
author's published 91.7%/97.7% is not a result measured on this application.

Since v0.42.190+434, `memoryRetrieval.localSemanticTiming` in the redacted
report includes model load, latest indexing run elapsed time/count and up to
eight retrieval samples for the current process. Each sample separates the
query embedding wait from native inference, distinguishes cache and fallback
paths, and reports total retrieval time and semantic-only selections. Null
timing means that operation was not observed in this process or sample. This
sampling uses existing operations and adds no persistence.

## Validation and remaining device checks

Candidate 6205e4ff (v0.42.189+433) passed independent CI 43812990054,
Android build 43812989961, 167 source validators, all 3455 Flutter tests,
native tests and packaged model/tokenizer hash checks. The original signing
certificate is unchanged. Tokenizer parity (10 cases) and source-index mutation
regressions passed. These are not device performance or recall-accuracy results.
Device checks must cover first indexing, archive restore, normal latency, simultaneous Live2D/TTS,
and relevance across paraphrases, unrelated queries and corrected facts.
QQ image review and animation selection are a separate second task; no changes here.
