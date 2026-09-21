# Live2D clean rollback · v0.42.0+244

## Current product state

The Sen-specific Live2D integration is fully removed from the production app. The APK no longer contains the Cubism Core AAR, Java Framework, shaders, Sen runtime, profile, outfit/action/emotion mappings, PlatformView, TTS mouth hook, gaze/headpat bridge, or Sen UI. The static portrait stage returns to its pre-Live2D behavior.

The natural-reply work from v0.41.97/v0.41.98 is deliberately retained. This rollback does not restore fixed assistant fallback lines and does not change personality, memory, desire, Cedar, TTS acoustics, or the floating pet.

## Legacy local-model cleanup

An update cannot remove files that an older APK already extracted into Android app-private storage. Therefore a renderer-independent cleanup control remains in both chat quick-panel variants:

- it reports whether the exact legacy `filesDir/sen-live2d` root exists and its file-byte total;
- it always asks for explicit confirmation before deletion;
- native code verifies that the canonical target is the direct `filesDir` child named `sen-live2d`;
- it deletes `current`, `staging`, `backup`, and any other contents under that one root, then clears only the legacy `sen_live2d` SharedPreferences index;
- it does not touch static portraits, chat data, attachments, backups, desktop-pet resources, or any broader directory.

The imported ZIP itself was never retained; older builds extracted its model contents into this root. The cleanup button removes those extracted model files.

## Validation status

GitHub Actions run `35642646319` passed the complete source/regression suite, Flutter analyze and tests, Android/Kotlin tests, release APK build, signing verification, existing payload checks, and the APK-name scan that rejects residual Live2D/Cubism files. Artifact `10659441135` and unpublished draft release `393217151` contain the candidate APK. Its SHA-256 is `e58122e12f1cc412ff29eccbf0575bb0ae73ba6b524419ea774ad2f5a3dc5684`.

True-device verification is still required for upgrade-time storage detection/deletion, persistence after restart, and regression coverage of the static portrait, chat, TTS, and IME behavior.

## Future Live2D re-entry

A replacement model starts as a new integration. Do not revive the removed Sen-specific renderer or infer model actions from the old preset catalog. The cleanup bridge may remain unchanged, or the future Live2D settings page may call the same channel after its own storage migration is explicitly designed.
