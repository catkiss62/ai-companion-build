package com.catkiss.senlive2dcompanion;

/** Presentation events, never persistent widget state. Revisions cannot extend a lease. */
final class CaicaiEmotionLease {
    private String event = "", emotion = "normal";
    private long start;
    private final java.util.LinkedHashSet<String> seen = new java.util.LinkedHashSet<>();
    boolean present(String id, String value, long now) {
        if (id.equals(event)) { if (weight(now) > 0) emotion=value; return false; }
        if (!seen.add(id)) return false;
        while (seen.size()>64) seen.remove(seen.iterator().next());
        event=id; emotion=value; start=now; return true;
    }
    String emotion() { return emotion; }
    float weight(long now) {
        double age=(now-start)/1_000_000_000.0;
        return event.isEmpty() ? 0 : (float)Math.max(0,Math.min(1,(4.5-age)/.38));
    }
}
