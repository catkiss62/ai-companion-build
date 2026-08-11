# v0.28.1 · Startup Recovery

First real-device checkpoint on Redmi K80 Ultra / Android 15 showed a permanent black Flutter surface before any permission prompt. The v0.28 entry point awaited `AppDatabase.ensureReady()` before `runApp()`, so any database/opening stall prevented the first Flutter frame entirely.

## Patch
- `runApp()` happens immediately.
- A visible startup recovery surface is painted before local database work begins.
- Database opening and device identity are separate visible phases with bounded waits.
- Startup exceptions are rendered on-screen in release builds.
- The database singleton caches an in-flight open so a timeout/retry cannot start competing opens.
- Includes the `DriveKey` import exposed by the first real Flutter release build.

No schema change. TTS payloads, Memory/Relationship semantics, Active Brain ownership and transfer protocol are unchanged.
