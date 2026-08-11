# v0.26 Transfer Hardening

## Ownership model

A relationship database belongs to one persistent `state_lineage_id`. `state_generation` is an ownership epoch, not a chat-message counter.

1. Active source acquires `transfer_lock` and waits for existing writers.
2. Export reserves `generation + 1` and a fresh `snapshot_id` inside SQLite.
3. Snapshot contains the frozen generation and its SHA-256.
4. Receiver verifies/imports into `active_brain=0, transfer_lock=1` and writes a local replay receipt in the same transaction.
5. Nearby receiver sends a takeover request bound to the exact snapshot identity.
6. Source native code atomically re-checks the identity and sets itself standby **before** ACK.
7. Target accepts only a matching ACK, then atomically becomes Active Brain and increments the generation once more.

The last increment means the package that created the new brain is already stale immediately after activation.

## Why receipts are local-only

`transfer_receipts` proves what this installation has already imported. Copying the source device's receipts would conflate two installations and weaken replay detection, so the table is omitted from `exportAll()` and is not deleted by an incoming full-state import.

## Network ambiguity

Safety preference is single-brain over availability:

- source fenced + ACK lost => source remains standby, target remains standby;
- target may use explicit manual takeover only after the user confirms the other device is down;
- wrong/old ACK cannot activate a target;
- source accepts takeover only for the exact currently frozen outbound generation.

## Foreign lineage

A fresh/pristine installation can adopt the incoming lineage. Replacing a non-pristine different lineage requires explicit destructive confirmation. This prevents an unrelated companion database from being silently overwritten.

## Manual fallback

The fallback package is not a second sync system. It transports the same Snapshot v2 payload through Android SAF:

`Snapshot ZIP -> PBKDF2-HMAC-SHA256(passphrase,salt) -> AES-256-GCM -> .aicomp`

The passphrase stays in memory only. GCM detects wrong passphrases/tampering; the inner state SHA-256 detects any snapshot inconsistency. Export pauses the source before the file is used; import remains standby until explicit takeover.

## Overlay ownership

`overlay_user_enabled` is a per-device user preference, not relationship state. Transfer therefore stops the running source overlay without changing that preference. Every persistent overlay/background-brain start path checks the SQLite Active Brain state, so standby cannot resurrect the companion service. On later activation, the existing preference can be reconciled.
