#!/usr/bin/env bash
set -euo pipefail

COMMIT='71825eed74683305b139a669b23ca5dc12f76857'
BASE="https://raw.githubusercontent.com/sixseeds/tarot-api/$COMMIT/cards"
DEST='assets/tarot/rws_major'
mkdir -p "$DEST"

cat > "$DEST/SHA256SUMS" <<'EOF'
557c6592b73107508eac65ef140d090d2ccd657ac5a2d5d4fe31c6c2ceacbcb5  ar00.jpg
e0569e468545abfd2987ec0af5d3c51da3a9d478e37077aeaa1d715ddfc9941b  ar01.jpg
0e87b5a22187a299334188c2e8fd178125151f9015c122f6946367489cfd252a  ar02.jpg
2f0a9885c4f4e68bbca4cb40d3d5f42d4c7559f914bb5b3765ee429c74c142df  ar03.jpg
7a800b57c5b7da7b493e6968da31325327134e98083e95ee75b3db6eaef7e868  ar04.jpg
68faba7f016b2d76b2fc2200f834279a0b08b7228767ae744fcdc70f9402699d  ar05.jpg
5a24e337a146568ebbbfa9783fa451d22c02bccd3cb7fe518afdb3ff396487fe  ar06.jpg
3906e01a159d3b7f1696e9094080e0a4ae95b2f4d4ca8b084131aba6ad133dd8  ar07.jpg
b222f1799b8dc46944d28f6079b1551011691dc439740371126e874fcf0c768f  ar08.jpg
0f86ac4560e598ced039665e21023d329e7a7e58872c46b3e9a9d85bb6cb2a50  ar09.jpg
2979bea7530572f408739757c87200772f6171a5249684cc9ee2a379108b3657  ar10.jpg
028645f4ed40a82035c410f4b7b5b00adbdcdf1c21ffd706cddeaf9227e0151d  ar11.jpg
0eacf7afe48e4b51c5405a8354ecb867a4d8868151137434ef84621e4d56359c  ar12.jpg
9e9cdd41a4d975691e79acc2358b45f4f2c58661431c3113a5ccf27477356a66  ar13.jpg
a306b373f8ff18270a2daabe3d89967eadd428e460c39ed717bda7bd38a1f009  ar14.jpg
f8e37102cbf2120270c0ed8c3e193b260d2f79dd5908bc9acbd48e8335083cf8  ar15.jpg
ab5ce9bf29f32b9cf61720b375fe35f23ce7e116ee1c648a9bf6832e17241163  ar16.jpg
20bb3e04c1655cc318031d94a024d84199cfeae2ca55e80d2d341c2d30435ac7  ar17.jpg
866474dc3de02bf3817495fd75d254dac2b9f36470f2f29ecb54de572f9dc70e  ar18.jpg
6c21ef99fef3807bafb26cd467464c8efc59e7312a688ae66285968e364c6450  ar19.jpg
1d670d30e651554051f1a04708a11c57583a92a2cc370b8c0fc54fb82f2ffbd3  ar20.jpg
f866b87a3c4422f96074080024860f46b5b3f456fcad74ca7aefdb5263bf0e69  ar21.jpg
EOF

pids=()
while read -r expected name; do
  (
    tmp="$DEST/$name.tmp"
    curl -fsSL --retry 4 --retry-delay 2 "$BASE/$name" -o "$tmp"
    actual="$(sha256sum "$tmp" | cut -d' ' -f1)"
    test "$actual" = "$expected"
    mv "$tmp" "$DEST/$name"
  ) &
  pids+=("$!")
done < "$DEST/SHA256SUMS"
for pid in "${pids[@]}"; do
  wait "$pid"
done

test "$(find "$DEST" -maxdepth 1 -type f -name 'ar*.jpg' | wc -l)" = '22'
echo 'Pinned 22-card Rider-Waite-Smith Major Arcana JPG pack restored.'
