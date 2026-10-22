package com.catkiss.senlive2dcompanion;
import org.junit.Test;
import static org.junit.Assert.*;

public class CaicaiSpeechMouthOwnerTest {
    @Test public void silentPhonemesStillOwnTheMouthAndRepeatedPlaybackRenewsLease() {
        var owner = new CaicaiSpeechMouthOwner();
        assertFalse(owner.active(0)); // Opening choreography may use mouth.
        owner.playback(true, 1_000_000_000L);
        assertTrue(owner.active(1_100_000_000L));
        // No amplitude appears in the ownership decision: a silent PCM block
        // is still PLAYSTATE_PLAYING and must suppress the angry mouth.
        owner.playback(true, 1_200_000_000L);
        assertTrue(owner.active(1_400_000_000L));
        owner.playback(false, 1_410_000_000L);
        assertFalse(owner.active(1_410_000_000L));
    }
    @Test public void lostTailOrRendererDoesNotLeaveExpressionMouthLocked() {
        var owner = new CaicaiSpeechMouthOwner();
        owner.playback(true, 1_000_000_000L);
        assertTrue(owner.active(1_249_999_999L));
        assertFalse(owner.active(1_250_000_000L));
        assertFalse(new CaicaiSpeechMouthOwner().active(1_100_000_000L));
    }
}
