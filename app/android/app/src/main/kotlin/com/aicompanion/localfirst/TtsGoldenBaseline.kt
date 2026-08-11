package com.aicompanion.localfirst

/** Golden local-TTS artifact fingerprints captured from the user-supplied MejuTTS v2.7 APK. */
internal object TtsGoldenBaseline {
    const val GOLDEN_APK_NAME = "MejuTTS_DoomsdayBridge_v2.7.apk"
    const val GOLDEN_APK_SHA256 = "63a8c10f5fc097205f7be8649bf9a60974e02714ef550b54eb5bd74bbc58c5e7"
    const val GOLDEN_REFERENCE = "MejuTTS v2.7 · 63a8c10f5fc0"
    data class Artifact(val sha256: String, val size: Long)
    val assets: Map<String, Artifact> = mapOf(
        "tts_models/bert/chinese-roberta-wwm-ext-large-distilled-fp16.mnn" to Artifact("756197286c18bdf78c30b1aede62b5fbf1608f7b5ae119fb24bd72374e5b987d", 31762468L),
        "tts_models/bert/meju.mnn" to Artifact("4205b8bbe80156093f56eb600d6c105ab0c1aea844fa2d3752ec80ccb5044e0c", 2922776L),
        "tts_models/bert/tokenizer.json" to Artifact("173796956820ea27bd14f76bf28162607ff4254807e2948253eb5b46f5bb643b", 268962L),
        "tts_models/bv2_model/config.json" to Artifact("bcc5241ffcf60613951b7b5ffb943ab1d58bfd6c5e28873ee244f67dd0f2a48a", 65L),
        "tts_models/bv2_model/meju.mnn" to Artifact("4205b8bbe80156093f56eb600d6c105ab0c1aea844fa2d3752ec80ccb5044e0c", 2922776L),
        "tts_models/bv2_model/meju_dec.mnn" to Artifact("1d1df6334919578d218f13a81c3fee1aac4b66619e74c7548ecd571092766584", 14842308L),
        "tts_models/bv2_model/meju_dp.mnn" to Artifact("50ffced8bac4419876fb454f5cf57da3461a5e5b641d0364a065a3f66e3c11a0", 1781772L),
        "tts_models/bv2_model/meju_emb.mnn" to Artifact("2c63f06ef1b69bffcceb721b61f265913233e17536ff8a3017035a45b9c8a611", 3004L),
        "tts_models/bv2_model/meju_enc_p.mnn" to Artifact("8b8d7d42e238bdfd04fdcc0331a8a37dd0506ed4a9c85cca931badaccc2530c3", 7579628L),
        "tts_models/bv2_model/meju_flow.mnn" to Artifact("dffaf4f22823ac4a0b26a439c362a41deac3c5efb2c012319d95bf3b9e593db0", 27863056L),
        "tts_models/bv2_model/meju_sdp.mnn" to Artifact("5f12548e4fb2b8e8483b4fc97c2f9b8f2faf6b28318c68c26cfa156bb91b9ece", 2922776L),
        "tts_models/preprocess/dict/README.md" to Artifact("8bcc7c2ed7dff082d9a99c09de0bfd72249bf3b5c4298a3af328da40cbd8cfd1", 683L),
        "tts_models/preprocess/dict/hmm_model.utf8" to Artifact("f17790586ac86dd048c8adffed052c4bd2b28ed0682972c1275e59040c0589a7", 519739L),
        "tts_models/preprocess/dict/idf.utf8" to Artifact("dbd1e03d72b2263cc8d84a4304ed77677eed9e7deaf43a1a5133bbba9733b535", 5998717L),
        "tts_models/preprocess/dict/jieba.dict.utf8" to Artifact("3043b77068e09c9904f27cad82f12b6ebe9dbdb5aeff3b25e45ab7f9c1122b55", 5071204L),
        "tts_models/preprocess/dict/pos_dict/char_state_tab.utf8" to Artifact("28b7be1dd7369766a51445af4d42e9a2ba4bf374c13be5bc1ca7721e27271dbb", 327139L),
        "tts_models/preprocess/dict/pos_dict/prob_emit.utf8" to Artifact("c33c4cb7edf3b3a5947df7209b6e9f267eae1f21335d9e2bd2521ea07105457a", 1687686L),
        "tts_models/preprocess/dict/pos_dict/prob_start.utf8" to Artifact("13623ea0e9300bdb597cb2da28770b7b385d6c0098d66e516083fb01b6bd5d96", 4347L),
        "tts_models/preprocess/dict/pos_dict/prob_trans.utf8" to Artifact("f22363e2307408293d180c6f9f6b5cb75879d52f722f7764fa2d3d0ae2400236", 124159L),
        "tts_models/preprocess/dict/stop_words.utf8" to Artifact("b788b8a939d2e2fe079abd579ea98f12f9fb84370bfd0dddd81bb9381f7ab42c", 8974L),
        "tts_models/preprocess/dict/user.dict.utf8" to Artifact("495bbf49270408a1234690e1e6a97328f30a482a7a72aa769e8a12e8714b0c62", 49L),
        "tts_models/preprocess/opencpop-strict.txt" to Artifact("d66bbb1380a8ebf17d7ace5bf4b459f3728a469eea2aaeae2aeb3969b88223ff", 4084L),
        "legacy_tts/runtime/runtime_01.jar" to Artifact("3e6ffaf1630498d2ed46cdd9c7ef2695774d54e4f08f87f37c18acd8015ed0b0", 6601845L),
        "legacy_tts/runtime/runtime_02.jar" to Artifact("1a56ee7a432a7e5ff11b57d561ad9105363537a1005724385a6616f2d4b35c2e", 2872L),
        "legacy_tts/runtime/runtime_03.jar" to Artifact("4c28b097df9a5d860bb980939f4e27ef0f22642fa1dd159832a2f7c44a2b50fd", 1145L),
        "legacy_tts/runtime/runtime_04.jar" to Artifact("795d354697ace04a4f7624e42a0d216405af8ad7196f68b929e788ed80859204", 115941L),
        "legacy_tts/runtime/runtime_05.jar" to Artifact("c3e9cd4640659ba79bb569a470de9db60361ae6b6902ead92e87bd8cb89c6981", 94374L),
        "legacy_tts/runtime/runtime_06.jar" to Artifact("ddbb44dacfb2da81ad746bd9227355f8ad02bb132dd3d6d7a1ee36bed2631aae", 24782L),
        "legacy_tts/runtime/runtime_07.jar" to Artifact("fc80751df27421e972b98692503b327df8afda3a584822be2223f16239784356", 5004L),
        "legacy_tts/runtime/runtime_08.jar" to Artifact("6d1df759be48b22d27065cbb07528ffc0f2ca643ea6ca87513ba902be8fb58aa", 34456L),
        "legacy_tts/runtime/runtime_09.jar" to Artifact("04f71fa9f51601084f36c48fd938c6f2ab0e9bebefcbfacde5b3352e6540f006", 1312734L),
    )
    val nativeLibraries: Map<String, Artifact> = mapOf(
        "libbertvits2.so" to Artifact("a599d482539fdbe01ccd82a9c688d0dce574c19dd681b15fd580185890e65792", 710848L),
        "libMNN.so" to Artifact("c1409cba5eae1450ed4d08bf0b0f002bdb409ee8439b501e2f46e78cb61cc9e1", 2686312L),
        "libMNN_Express.so" to Artifact("69acb50888a67af8915f51c966b02a799914d75b5b92a6f709ee1fa2b7821b44", 806584L),
        "libMNN_Vulkan.so" to Artifact("e5cfe760772cf23032d1bd8973dec9127f946387cea2fe4638c3996a2c007324", 728576L),
        "libcppjieba.so" to Artifact("6886703b629f6ecd11d8afe887b8e6b91c87d9f2747340ba518b59939d61d4a2", 1270872L),
        "libcpptokenizer.so" to Artifact("17cacda7a9dd59ce681492674bc44074fe6e5d28b19423727ed041b416c4661f", 6949048L),
    )
    const val TOTAL_ARTIFACTS = 37
}
