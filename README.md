# AI Companion

The complete Flutter/Android project lives in `app/` and is the repository's single source of truth.

## Start here

- Current evergreen ledger: [AI_Companion_当前总账.md](AI_Companion_当前总账.md). Read the top handoff entry first; search the preserved history only for the module being changed.
- Documentation map: [app/docs/DOCUMENTATION_MAP.md](app/docs/DOCUMENTATION_MAP.md)
- Build: run `.github/workflows/build-apk.yml` or follow [app/docs/BUILDING.md](app/docs/BUILDING.md).
- Clean Freeze: see [app/docs/CLEAN_FREEZE_v0.31.5.md](app/docs/CLEAN_FREEZE_v0.31.5.md).

Only `AI_Companion_当前总账.md` is the current cross-window status source. Retired ledgers and superseded plans remain recoverable from Git history, but are not kept in the working tree.

## CI scope

Pull-request synchronizations that change only the evergreen ledger, repository READMEs, or files under `app/docs/` run the lightweight change-scope check and skip the full APK job. Any project source, asset, configuration, workflow, mixed, or indeterminate change still runs the complete validation and release build. Manual workflow dispatches always run the full build.
