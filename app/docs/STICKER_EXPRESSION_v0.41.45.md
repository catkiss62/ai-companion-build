# Sticker expression layer · v0.41.45

## Purpose

Stickers are a local expression layer for one-to-one chat. They decorate an
ordinary assistant reply after its content, emotion and Conversation Move have
already been selected. They are not a new Desire, Thought, autonomous action,
language-learning signal or reason to send another proactive message.

The primary mechanism reference is
[`yyh-001/dsh-meme`](https://github.com/yyh-001/dsh-meme), with the companion
pack format/catalogue at
[`yyh-001/dsh-meme-packs`](https://github.com/yyh-001/dsh-meme-packs). The
earlier QQ-group research source
[`nanbengxian-cyber/dafeiyu-qq-bot`](https://github.com/nanbengxian-cyber/dafeiyu-qq-bot)
is retained for traceability only; its group-silence/language-adaptation ideas
are intentionally not part of this feature.

## Pack contract

AI Companion imports a local ZIP containing exactly one pack root:

```text
pack-id/
  manifest.json
  index.db
  memes/
    0001.gif
    0002.jpg
```

It also accepts one bundle ZIP whose root directly contains 2–20 individual
pack ZIPs and no folders or unrelated files:

```text
AI-Companion-Sticker-Bundle.zip
  personal-001.zip
  dafeiyu-001.zip
  official-001.zip
```

All child packs are validated before any live pack is replaced. Duplicate pack
IDs, nested directories, extra files and aggregate archive-limit violations
reject the whole bundle; a failed child cannot leave a partially imported set.

`manifest.json` contains a stable lowercase ID, display name, description and
license label. `index.db` retains the dsh `memes` fields `path`, `tag`,
`file_name`, `caption`, and `keywords`. AI Companion additionally understands:

- `tone_scope`: `general`, `bold`, `nsfw`, or `disabled`;
- `intensity`: 1–3;
- `enabled`: 0/1.

Natural-language filenames are provenance only. Runtime sampling uses the
indexed path and never treats words such as “万能” or an old role name as a
weight. Unknown upstream tags fall back to `daily`; `speechless` is explicitly
mapped to `sad` locally.

ZIP import rejects traversal, absolute paths, links/special entries, duplicate
paths, unsupported formats, missing indexed files, oversized archives and
oversized individual images. Installation uses an atomic private-directory
swap. Pack files remain on the device and are not committed to the public
repository or added to the simulated-phone album. Only a sticker actually sent
is copied to that chat message's attachment store. v0.41.45 does not include
pack media in state backup; the settings page says this directly so a restore
cannot silently promise media portability.

## Runtime policy

The expression mode is `off`, `low`, `natural`, or `frequent`, with an ordinary
reply opportunity of 0%, 12%, 24%, or 42%. This is not an autonomy probability:
it runs only after the user has already received a normal reply.

Selection requires all of the following:

1. response mode is lightweight `casual`, not task/deep/feedback/sensitive;
2. the chosen speech act is a reaction, self-share, tease, attention/need bid,
   or natural pause/close;
3. the turn did not execute an Agent tool, and visible text is short with no URL
   or code block;
4. an enabled pack contains an item matching the assistant's existing emotion;
5. the item is not in the recent 18-item cooldown.

Pack choice is balanced before item choice, so a large pack does not erase a
small one. Within the selected mood, caption/keyword overlap may narrow the
candidate set; deterministic seeded sampling then chooses among the best few.
`bold` images require a correspondingly strong speech act. `nsfw` images require
the existing NSFW route to be active. `disabled` images never enter sampling.
No extra model call or image-recognition request is made.

The selected original is copied into the existing durable chat-attachment
store. The attachment and assistant message commit in the same database
transaction. Failed/obsolete generation deletes its prepared files. Animated
GIFs render from the original file. Sticker bubbles use a consistent 180dp
display width while height follows the source aspect ratio within the existing
height cap; ordinary photos keep their existing layout. History receives the
indexed first-person caption (`我发送了一张表情包`) rather than mislabelling it
as a user image. This gives the next turn durable awareness of who sent the
sticker and what it depicted without claiming an exact image before its file
transaction succeeds.

This is also the mandatory contract for later ordinary image sending: an
assistant-owned attachment must durably retain media type, source provenance
and an available content summary, and history must describe it in first person.
A download, permission, ownership or transaction failure must never create a
false memory that the assistant sent an image.

## User pack review

The supplied 68-image private pack was reviewed from first frames plus three
representative frames for every GIF. Its internal result is 44 `general`, 17
`bold`, 5 `nsfw`, and 2 default-disabled images. The two disabled items are a
self-harm joke and a group-specific feces joke. Original bytes and original
filenames are retained in the private index, while runtime paths are numeric.
Private media and its detailed captions are not part of the public repository.

## Validation boundary

Static tests cover tag/emotion mapping, path traversal and bundle-shape
rejection, single/bundle compatibility, and first-person prompt history. CI
must still prove Flutter analyze/tests, release
APK construction, signing and assets. A real-device pass must separately prove
three-pack bundle import, simulated-album non-pollution, ordinary static/GIF
display, persistence after restart, no vision quota use, safe-mode filtering,
self-awareness on the following turn, and that proactive/autonomous frequency
remains unchanged.
