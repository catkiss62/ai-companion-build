# v0.13 Internal Validation

## Static checks

- Manifest/XML parse.
- Kotlin/Dart delimiter balance.
- Dart relative-import resolution.
- Conservative duplicate adjacent Dart declaration scan.
- True overlay tokens present in `OverlayBubbleService`.
- No `OverlayChatActivity.kt`.
- No service-hosted `FlutterView` import.
- Notifications use service/foreground-service PendingIntent, not chat Activity PendingIntent.
- MainActivity collapses expanded overlay when rich App resumes.
- `BackgroundSystemBridge` exposes overlay unread set/clear APIs.
- Runtime diagnostics expose `overlayChatExpanded`.
- Background command server is registered before heartbeat scheduling.
- `messagesBefore()` exists for history paging.
- Version is 0.13; SQLite schema remains 10.
- v0.12 TTS critical baseline: 41 files, 0 changed, 0 missing.

## Not claimed

No Flutter SDK or Android SDK is installed in this environment, therefore this revision does not claim:

- `flutter analyze`
- Flutter test runner
- Gradle/AGP compilation
- installable APK
- real-device overlay/IME behavior

`kotlinc` without Android classes is only useful for parser-level sanity; unresolved Android/Google symbols are expected and are not treated as Android compilation evidence.
