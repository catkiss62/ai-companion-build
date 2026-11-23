#!/usr/bin/env bash
# Mirrors the project's existing private draft asset flow used by Genie.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
dest="$here/../../android/app/generated/whale-private"
repo=catkiss62/ai-companion-build
tag=whale-ar-private-runtime-v1
name=whale-ar-runtime-v1.zip
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
if [[ $# == 1 ]]; then
    archive=$(realpath "$1")
else
    release=$(gh api --paginate "repos/$repo/releases?per_page=100" --jq ".[] | select(.draft and .tag_name==\"$tag\") | .id")
    [[ "$release" =~ ^[0-9]+$ ]]
    asset=$(gh api --paginate "repos/$repo/releases/$release/assets?per_page=100" --jq ".[] | select(.name==\"$name\") | .id")
    [[ "$asset" =~ ^[0-9]+$ ]]
    archive="$work/$name"
    gh api -H 'Accept: application/octet-stream' "repos/$repo/releases/assets/$asset" > "$archive"
fi
echo "6f46a99346ad3de5f49847d3e7752b124cc76efda931ef39a22b4a99c72cfb21  $archive" | sha256sum --check --status
mkdir -p "$dest"
unzip -oq "$archive" -d "$dest"
