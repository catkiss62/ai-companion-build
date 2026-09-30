# Offline assets for Memory Galaxy

These assets keep the supplied memory galaxy template usable without a network connection. The template's Three.js revision, font families, weights and italic styles are preserved.

## Three.js

- Source: https://github.com/mrdoob/three.js/tree/r160
- Version: r160 / 0.160.0, matching the supplied template's import map.
- The `build/three.module.js` file and the selected `examples/jsm` modules are copied without modification, with their relative import layout intact.
- License: MIT, reproduced in `three/LICENSE` and source headers.

## Fonts

- Source: https://github.com/fontsource/font-files/tree/c3f4e3e5a664d2c3002e800050ce809a790d7281
- Cormorant Garamond: original static 400 italic WOFF2 subsets.
- Playfair Display: original static 600 italic WOFF2 subsets.
- Noto Serif SC: 101 original variable WOFF2 Unicode subsets, weight range 200–900, including the template's 300, 400 and 500 weights.
- All Unicode ranges from the original Fontsource stylesheets are retained; no character sampling or custom glyph reduction is applied.
- `fonts/fonts.css` combines the three family stylesheets, adjusts paths to the adjacent local WOFF2 files, removes unused WOFF fallbacks, and aliases the variable Noto family to the template's `Noto Serif SC` name. Font binaries are copied without modification.
- Font licenses: SIL Open Font License 1.1, reproduced in the three `fonts/LICENSE-*.txt` files.

`SOURCES.json` records the pinned sources and upstream Git blob hashes of every font binary. Asset bytes are checked again during APK packaging.
