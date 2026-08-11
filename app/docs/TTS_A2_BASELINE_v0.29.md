# v0.29.0 · Meju A2 TTS baseline

## Verified source of truth

Real-device comparison uses the user-supplied `MejuTTS_A2_OriginalNative_v2.5.apk` as the behavioral baseline.

- `libbertvits2.so` packaged entry: 710,848 bytes.
- Original ELF body: first 635,352 bytes.
- Original ELF SHA-256: `a1ca5180532aae3a7c378371f6ddb44bbf35d8826a8b8750db4fd12179c5551b`.
- Remaining 75,496 bytes are zero alignment padding.
- AI Companion's packaged native file is byte-identical to that padded v2.5 entry.

The model/JAR/native payload is therefore frozen. v0.29.0 changes only scheduling/preprocessing around the already-working legacy runtime.

## A2 behavior restored

The speech path now mirrors the proven A2 flow:

1. speech-only cleanup (`Yuki -> 有希`, removable bracket blocks, markdown hygiene);
2. split only on `。！？；.!?;`;
3. no comma/ideographic-comma/newline/ellipsis split;
4. no 72/116-character fallback;
5. submit all sentence generation requests without waiting for playback;
6. keep one FIFO native MNN generation worker for runtime safety;
7. play sentence 1 as soon as its WAV is ready while later WAVs continue generating;
8. preserve sentence order and isolate one-sentence failures;
9. use ~200 ms gap only when the next generated WAV is already queued at playback completion;
10. `stop()` fences stale generation and stops AudioTrack without force-interrupting MNN.

The historical 60-second pending-request cleanup is not reintroduced.

## Architectural boundary

Flutter never embeds the old HTML/WebView shell. The compatibility path remains:

`Flutter -> TtsPlaybackQueue -> NativeTtsProvider -> NativeTtsBridge -> LegacyTtsRuntime -> LocalTTSEngine/JNI/MNN`

Generation and playback are separate native calls so playback no longer blocks the one inference worker.
