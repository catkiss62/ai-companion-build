package com.catkiss.senlive2dcompanion;

/** Actual PCM playback owns the whole mouth, including silent phonemes.
 * A short heartbeat lease also retires a lost/stale playback without trapping
 * the face after cancellation or a view/renderer replacement. */
final class CaicaiSpeechMouthOwner {
    static final long LEASE_NANOS = 250_000_000L;
    private long deadline;
    void playback(boolean playing, long now) { deadline = playing ? now + LEASE_NANOS : 0L; }
    boolean active(long now) { return deadline > now; }
}
