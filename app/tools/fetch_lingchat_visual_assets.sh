#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_COMMIT='eae0d667413e490c3653488d43ce9b4464e07fda'
RAW_ROOT="https://raw.githubusercontent.com/SlimeBoyOwO/LingChat/${UPSTREAM_COMMIT}"
LFS_BATCH='https://github.com/SlimeBoyOwO/LingChat.git/info/lfs/objects/batch'
ASSET_ROOT="$(cd "$(dirname "$0")/.." && pwd)/assets/lingchat"

download_lfs() {
  local source_path="$1"
  local destination="$2"
  local encoded pointer oid size response href actual
  encoded="$(jq -rn --arg value "$source_path" '$value|@uri')"
  pointer="$(curl -sS --fail --retry 3 --max-time 60 "${RAW_ROOT}/${encoded}")"
  oid="$(sed -n 's/^oid sha256://p' <<<"$pointer")"
  size="$(sed -n 's/^size //p' <<<"$pointer")"
  test -n "$oid"
  test -n "$size"
  if test -f "$destination" && test "$(wc -c < "$destination")" = "$size"; then
    actual="$(sha256sum "$destination" | cut -d' ' -f1)"
    if test "$actual" = "$oid"; then
      printf '%s  %s (reused)\n' "$actual" "${destination#${ASSET_ROOT}/}"
      return
    fi
  fi
  response="$(curl -sS --fail --retry 3 --max-time 60 \
    -H 'Accept: application/vnd.git-lfs+json' \
    -H 'Content-Type: application/vnd.git-lfs+json' \
    -H 'User-Agent: git-lfs/3.0' \
    -d "{\"operation\":\"download\",\"transfers\":[\"basic\"],\"objects\":[{\"oid\":\"${oid}\",\"size\":${size}}]}" \
    "$LFS_BATCH")"
  href="$(jq -er '.objects[0].actions.download.href' <<<"$response")"
  mkdir -p "$(dirname "$destination")"
  curl -sS --fail --retry 3 --max-time 180 -o "$destination" "$href"
  actual="$(sha256sum "$destination" | cut -d' ' -f1)"
  test "$actual" = "$oid"
  printf '%s  %s\n' "$actual" "${destination#${ASSET_ROOT}/}"
}

while IFS='|' read -r source relative; do
  [[ -z "$source" || "$source" == \#* ]] && continue
  download_lfs "$source" "$ASSET_ROOT/$relative"
done <<'ASSETS'
data/game_data/backgrounds/白天.webp|background/day.webp
data/game_data/backgrounds/夜晚.webp|background/night.webp
data/game_data/characters/DeepSeek/avatar/头像.webp|deepseek/avatar.webp
data/game_data/characters/DeepSeek/avatar/正常.webp|deepseek/normal.webp
data/game_data/characters/DeepSeek/avatar/平静.webp|deepseek/calm.webp
data/game_data/characters/DeepSeek/avatar/高兴.webp|deepseek/happy.webp
data/game_data/characters/DeepSeek/avatar/兴奋.webp|deepseek/excited.webp
data/game_data/characters/DeepSeek/avatar/调皮.webp|deepseek/playful.webp
data/game_data/characters/DeepSeek/avatar/自信.webp|deepseek/confident.webp
data/game_data/characters/DeepSeek/avatar/认真.webp|deepseek/serious.webp
data/game_data/characters/DeepSeek/avatar/疑惑.webp|deepseek/confused.webp
data/game_data/characters/DeepSeek/avatar/无奈.webp|deepseek/helpless.webp
data/game_data/characters/DeepSeek/avatar/担心.webp|deepseek/worried.webp
data/game_data/characters/DeepSeek/avatar/惊讶.webp|deepseek/surprised.webp
data/game_data/characters/DeepSeek/avatar/慌张.webp|deepseek/flustered.webp
data/game_data/characters/DeepSeek/avatar/害羞.webp|deepseek/shy.webp
data/game_data/characters/DeepSeek/avatar/心动.webp|deepseek/affection.webp
data/game_data/characters/DeepSeek/avatar/生气.webp|deepseek/angry.webp
data/game_data/characters/DeepSeek/avatar/伤心.webp|deepseek/sad.webp
data/game_data/characters/DeepSeek/avatar/厌恶.webp|deepseek/disgust.webp
data/game_data/characters/DeepSeek/avatar/害怕.webp|deepseek/afraid.webp
data/game_data/characters/DeepSeek/avatar/紧张.webp|deepseek/tense.webp
data/game_data/characters/DeepSeek/avatar/羞耻.webp|deepseek/ashamed.webp
public/audio_effects/伤心.wav|audio/sad.wav
public/audio_effects/叹气.wav|audio/sigh.wav
public/audio_effects/喜悦.wav|audio/joy.wav
public/audio_effects/喜爱.wav|audio/affection.wav
public/audio_effects/困扰.wav|audio/troubled.wav
public/audio_effects/害羞.wav|audio/shy.wav
public/audio_effects/察觉.wav|audio/noticed.wav
public/audio_effects/尴尬.wav|audio/awkward.wav
public/audio_effects/思考.wav|audio/thinking.wav
public/audio_effects/惊讶.wav|audio/surprised.wav
public/audio_effects/无语.wav|audio/speechless.wav
public/audio_effects/生气.wav|audio/angry.wav
public/audio_effects/疑问.wav|audio/question.wav
public/audio_effects/对话.wav|audio/dialogue.wav
public/audio_effects/achievement_common.wav|audio/achievement_common.wav
public/audio_effects/achievement_rare.wav|audio/achievement_rare.wav
public/audio_effects/厌恶.wav|audio/disgust.wav
public/audio_effects/愉快.wav|audio/pleasant.wav
public/audio_effects/流汗.wav|audio/sweat.wav
public/audio_effects/聊天.wav|audio/chat.wav
public/audio_effects/角色音量测试.wav|audio/role_volume_test.wav
public/audio_effects/转场.wav|audio/transition.wav
public/audio_effects/震惊.wav|audio/shock.wav
public/pictures/animation/AI思考.webp|effects/ai_thinking.webp
public/pictures/animation/叹气.webp|effects/sigh.webp
public/pictures/animation/害羞.webp|effects/shy.webp
public/pictures/animation/察觉.webp|effects/noticed.webp
public/pictures/animation/心动.webp|effects/heart.webp
public/pictures/animation/惊讶.webp|effects/surprised.webp
public/pictures/animation/慌乱.webp|effects/flustered.webp
public/pictures/animation/流汗.webp|effects/sweat.webp
public/pictures/animation/流泪.webp|effects/tears.webp
public/pictures/animation/生气.webp|effects/angry.webp
public/pictures/animation/生气2.webp|effects/angry_alt.webp
public/pictures/animation/疑问.webp|effects/question.webp
public/pictures/animation/紧张.webp|effects/nervous.webp
public/pictures/animation/聊天.webp|effects/dialogue.webp
public/pictures/animation/难为情.webp|effects/embarrassed.webp
public/pictures/animation/高兴.webp|effects/happy.webp
ASSETS

