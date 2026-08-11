# v0.29.0 · GitHub clean baseline

v0.28.1-v0.28.5 used a bootstrap ZIP split into five parts plus sequential patch files. That was useful for first-device debugging, but is not the long-term repository shape.

## Migration rule

The one-time promotion workflow reconstructs v0.28, applies v0.28.1-v0.28.5 and the v0.29.0 A2 patch, then commits the resulting complete Flutter project under `app/`.

The promotion workflow deliberately does **not** delete the old parts/patches. They remain until a clean-source build from `app/` succeeds.

After that successful clean build, the old bootstrap files may be deleted or moved to archive. Daily builds must use only `app/`.

## Target repository shape

```text
app/
  android/
  lib/
  test/
  tools/
  docs/
  pubspec.yaml
.github/
  workflows/
    build-apk.yml
README.md
```

The production project source is `app/`; the historical split ZIP and patch chain are no longer build inputs.
