# Internal Validation · v0.9

Validation completed in the source-only environment:

- Dart files scanned: 76
- Dart test files present: 15
- Relative import existence: pass
- Dart bracket/string/comment structural scan: pass
- pubspec YAML parse: pass
- Android XML parse: pass
- package/version consistency: pass (`0.9.0+9`)
- six default rule layers present: 6/6
- legacy hard novel/age/AI-hiding rules absent from the six defaults
- fresh SQLite schema smoke: 17 required tables present
- thought lifecycle columns present on fresh schema
- v6 -> v8 SQLite migration smoke: pass
- legacy reference chunks receive a document container during migration
- legacy fixation thought becomes lifecycle `fixation`
- snapshot export/import table coverage includes:
  - reference_documents
  - rule_layers
  - thought_lifecycle_events
  - proactive_feedback
- TTS native/model/runtime files compared with v0.7 baseline: 37 files, 0 changed

Not executable in this environment:

- `flutter analyze`
- Flutter widget/unit test runner
- Gradle APK build
- Android real-device background/overlay/Nearby/native-TTS runtime

Those remain for a later checkpoint where real-device behavior or human perception is actually required.
