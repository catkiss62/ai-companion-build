package com.aicompanion.localfirst

/** Fingerprints for the user-validated Chinese local-TTS payload from 完整文件(1).zip. */
internal object TtsGoldenBaseline {
    const val GOLDEN_APK_NAME = "完整文件(1).zip"
    const val GOLDEN_APK_SHA256 = "b72ebc8544de88ee368946d2ac824ea1641377ddbe6e2da378d4112c379a9671"
    const val GOLDEN_REFERENCE = "新版妹居本地 TTS · b72ebc8544de"

    data class Artifact(val sha256: String, val size: Long)

    val assets: Map<String, Artifact> = mapOf(
        "legacy_tts/pinyin/pinyin_dict_char.txt" to Artifact("981eba86a5ba114830e59167d588992eb3b5691f7ca584ae47c539e53952b5da", 489767L),
        "legacy_tts/pinyin/pinyin_dict_char_define.txt" to Artifact("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", 0L),
        "legacy_tts/pinyin/pinyin_dict_phrase.txt" to Artifact("a959653ddd712f39665bbe1da4a7f8a67fbe592fcceb61ce32f32c0a75dac775", 1159971L),
        "legacy_tts/pinyin/pinyin_dict_phrase_define.txt" to Artifact("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", 0L),
        "legacy_tts/pinyin/pinyin_dict_tone.txt" to Artifact("a00d943ad3ad7bb4ff2e9da9dfaa5302f6e10d9611aa24f449e327e01e249715", 277L),
        "legacy_tts/runtime/runtime_01.jar" to Artifact("4de6c823dcc4aec19b4dc40859d6a17aa2ab445f11665f197a238682ab93610c", 15310085L),
        "legacy_tts/runtime/runtime_02.jar" to Artifact("eb1669133ff6529be69d9e183d00d75dc7fe23b1cecb1f2a101bf5688c220d7d", 3456136L),
        "tts_models/bert/zh/chinese-roberta-wwm-ext-large-distilled-fp16.mnn" to Artifact("756197286c18bdf78c30b1aede62b5fbf1608f7b5ae119fb24bd72374e5b987d", 31762468L),
        "tts_models/bert/zh/tokenizer.json" to Artifact("7398d782758fabcb399215b76239cb05d787252a0724800948a3c25c0c4de56c", 268957L),
        "tts_models/bv2_model/zh/config.json" to Artifact("7afffd9e9720ab740aa5f39c5fdc7ae7df37fd995e785ad60600e86207fbad9b", 115L),
        "tts_models/bv2_model/zh/meju_dec.mnn" to Artifact("1d1df6334919578d218f13a81c3fee1aac4b66619e74c7548ecd571092766584", 14842308L),
        "tts_models/bv2_model/zh/meju_dp.mnn" to Artifact("50ffced8bac4419876fb454f5cf57da3461a5e5b641d0364a065a3f66e3c11a0", 1781772L),
        "tts_models/bv2_model/zh/meju_emb.mnn" to Artifact("2c63f06ef1b69bffcceb721b61f265913233e17536ff8a3017035a45b9c8a611", 3004L),
        "tts_models/bv2_model/zh/meju_enc.mnn" to Artifact("8b8d7d42e238bdfd04fdcc0331a8a37dd0506ed4a9c85cca931badaccc2530c3", 7579628L),
        "tts_models/bv2_model/zh/meju_flow.mnn" to Artifact("dffaf4f22823ac4a0b26a439c362a41deac3c5efb2c012319d95bf3b9e593db0", 27863056L),
        "tts_models/bv2_model/zh/meju_sdp.mnn" to Artifact("5f12548e4fb2b8e8483b4fc97c2f9b8f2faf6b28318c68c26cfa156bb91b9ece", 2922776L),
        "tts_models/preprocess/zh/dict/README.md" to Artifact("324dbf050d1516b8eb938b02d19a3f90cc67c97e9fc002033595c54c0cd5cd9e", 714L),
        "tts_models/preprocess/zh/dict/hmm_model.utf8" to Artifact("c2781984c4c6be66862ff1bc9aace264256bcd174cd900d7f3725debe6c71255", 519773L),
        "tts_models/preprocess/zh/dict/idf.utf8" to Artifact("d91455238e015eb0af6dd9539d55d5c4f5059513724545e1b057ed696438c663", 6257543L),
        "tts_models/preprocess/zh/dict/jieba.dict.utf8" to Artifact("59578ca2e4bf8b0ca9de879d6484fe70453cb7d46dbc430d15bf943541d5a330", 5420186L),
        "tts_models/preprocess/zh/dict/pos_dict/char_state_tab.utf8" to Artifact("d5e2f71cfb65aeeda9899b0268aa3fb2ce917813c5b5f89d4393f5ca39e030c0", 333792L),
        "tts_models/preprocess/zh/dict/pos_dict/prob_emit.utf8" to Artifact("5f4dca59263df0f2a1c3cf706daf0222619a979315a94b3f05fd750951a01ff0", 1687852L),
        "tts_models/preprocess/zh/dict/pos_dict/prob_start.utf8" to Artifact("46446f353d293b934d6bacb4f8e16adc2535ff2e72bc0712de6846c33d732993", 4606L),
        "tts_models/preprocess/zh/dict/pos_dict/prob_trans.utf8" to Artifact("5c051d34df75d414bf41d8df2b080961e3760b900e8f13e5f891df3cb4ea7e03", 129381L),
        "tts_models/preprocess/zh/dict/stop_words.utf8" to Artifact("01190ee2a5199f1eafaa90a4d192420d3389ff17a81772a303c8912a1882a485", 10508L),
        "tts_models/preprocess/zh/dict/user.dict.utf8" to Artifact("88b5d41305b7fc121dbf0c762b708a3c863fa4ac0769316b1819f44cd452d22b", 53L),
        "tts_models/preprocess/zh/opencpop-strict.txt" to Artifact("86c4b30928e3a4305c9148058c9e2e56b04ce741363fedff382421f4a1e3709d", 4513L),
    )

    val nativeLibraries: Map<String, Artifact> = mapOf(
        "libMNN.so" to Artifact("c1409cba5eae1450ed4d08bf0b0f002bdb409ee8439b501e2f46e78cb61cc9e1", 2686312L),
        "libMNN_Express.so" to Artifact("69acb50888a67af8915f51c966b02a799914d75b5b92a6f709ee1fa2b7821b44", 806584L),
        "libbertvits2.so" to Artifact("a6f11da0df792a82820b833f1b6951078179d16c4e15dd8a6abc18d52d227f08", 690920L),
        "libcppjieba.so" to Artifact("540462127cd2ccf1b0819aa15eed316b611f8fdc0f6609154ca684b207b48caa", 1033320L),
        "libcpptokenizer.so" to Artifact("15fee22b59cb8ea40fa46d772bc776e59d71e929f063cfd498fb91c5f9981f0f", 8028416L),
    )

    const val TOTAL_ARTIFACTS = 32
}
