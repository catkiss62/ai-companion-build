package com.catkiss.senlive2dcompanion;

import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.Map;
import java.util.Set;

/** Only acquired speech presets can be retired; heartbeats never replay accents. */
final class CaicaiSpeechPresetLease {
    interface Target {
        boolean acquire(String name);
        void release(String name);
    }
    private final Map<String, Long> owned = new LinkedHashMap<>();
    private String cue = "";
    boolean owns(String name) { return owned.containsKey(name); }
    static long releaseAfterNanos(String name) {
        // .38s native fade-out is part of the total 1.2/1.6/2.0s wink time.
        if ("wink".equals(name)) return 820_000_000L;
        if ("wink吐舌".equals(name)) return 1_220_000_000L;
        if ("比耶wink吐舌".equals(name)) return 1_620_000_000L;
        return 4_120_000_000L;
    }
    static boolean face(String name) {
        return java.util.Arrays.asList("1爱心","1生气","1红脸","1钱钱","1黑脸","1星星眼","1流泪").contains(name);
    }
    static boolean wink(String name) {
        return java.util.Arrays.asList("wink","wink吐舌","比耶wink吐舌").contains(name);
    }
    static boolean action(String name) {
        return java.util.Arrays.asList("2奶茶","2插手","2比耶","2点单","2菜单","2餐盘左","2餐盘右").contains(name);
    }
    void cue(String key, String face, String wink, String action, boolean animate,
             long now, Target target) {
        if (key.equals(cue)) return;
        cue = key;
        Set<String> next = new LinkedHashSet<>();
        if (animate) {
            if (face(face)) next.add(face);
            if (wink(wink)) next.add(wink);
            if (action(action)) next.add(action);
        }
        for (String name : new LinkedHashSet<>(owned.keySet())) {
            if (!next.contains(name)) { owned.remove(name); target.release(name); }
        }
        for (String name : next) {
            if (owned.containsKey(name) || target.acquire(name)) {
                owned.put(name, now + releaseAfterNanos(name));
            }
        }
    }
    void tick(long now, Target target) {
        if (owned.isEmpty()) return;
        for (String name : new LinkedHashSet<>(owned.keySet())) {
            if (now >= owned.get(name)) { owned.remove(name); target.release(name); }
        }
    }
    void release(Target target) {
        if (owned.isEmpty() && cue.isEmpty()) return;
        for (String name : new LinkedHashSet<>(owned.keySet())) target.release(name);
        owned.clear(); cue = "";
    }
    static boolean mouthParameter(String id) {
        // Tongue OUT is a separate authored wink accent. Jaw opening and mouth
        // shape belong to PCM and never to a real-audio preset.
        return id.toLowerCase(java.util.Locale.ROOT).contains("mouth")
            || "SHRUG".equals(id) || "PUCKER".equals(id);
    }
}
