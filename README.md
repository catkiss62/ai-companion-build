# AI Companion

The in-app Fate Wheel adapts the original tag taxonomy and slot-machine
interaction. Based on Ruota della Fortuna by Copper (29-Cu):
https://github.com/29-Cu/Ruota-della-Fortuna . See
`app/assets/fate_wheel/LICENSE` for the original license and attribution.

The complete Flutter/Android project lives in `app/` and is the repository's single source of truth.

## Start here

- Current development branch (2026-10-25): [agent/v042107-review-recovery](https://github.com/catkiss62/ai-companion-build/tree/agent/v042107-review-recovery). Confirm the branch before searching: the default `main` branch does not contain all current development features.
- AI handoff and Chinese/English feature map: [AI_START_HERE.md](AI_START_HERE.md).
- Current evergreen ledger: [app/docs/ledger/AI_Companion_总账_v3.md](app/docs/ledger/AI_Companion_总账_v3.md). Read the top handoff snapshot first; search history only for the module being changed.
- Permanent legacy ledger entry: [AI_Companion_当前总账.md](AI_Companion_当前总账.md).
- Documentation map: [app/docs/DOCUMENTATION_MAP.md](app/docs/DOCUMENTATION_MAP.md)
- Repository maintenance: [app/docs/REPOSITORY_MAINTENANCE.md](app/docs/REPOSITORY_MAINTENANCE.md)
- Build: run `.github/workflows/build-apk.yml` or follow [app/docs/BUILDING.md](app/docs/BUILDING.md).
- Clean Freeze: see [app/docs/CLEAN_FREEZE_v0.31.5.md](app/docs/CLEAN_FREEZE_v0.31.5.md).

Only `app/docs/ledger/AI_Companion_总账_v3.md` is the writable current cross-window status source. The root ledger preserves the v2 read-only history and redirects readers to v3. Retired material remains historical evidence, not a second current task ledger.

## CI scope

Pull-request synchronizations that change only the evergreen ledger, repository READMEs, or files under `app/docs/` run the lightweight change-scope check and skip the full APK job. Any project source, asset, configuration, workflow, mixed, or indeterminate change still runs the complete validation and release build. Manual workflow dispatches always run the full build.

## Current test build

The [current ledger](app/docs/ledger/AI_Companion_总账_v3.md) records the latest delivered APK, exact source and CI evidence, and remaining device checks. Work in progress is listed separately from delivered builds.
