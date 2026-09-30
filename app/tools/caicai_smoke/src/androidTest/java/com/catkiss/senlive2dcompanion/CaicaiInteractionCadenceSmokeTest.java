package com.catkiss.senlive2dcompanion;

import androidx.test.ext.junit.runners.AndroidJUnit4;
import org.junit.Test;
import org.junit.runner.RunWith;
import java.util.HashMap;
import java.util.Map;
import java.util.Random;
import static org.junit.Assert.*;

@RunWith(AndroidJUnit4.class)
public class CaicaiInteractionCadenceSmokeTest {
    private static final class Pose implements CaicaiParameterPlan.Target {
        final Map<String, Float> values = new HashMap<>();
        public boolean accepts(String id) { return true; }
        public float current(String id) { return values.getOrDefault(id, id.contains("Open") ? 1f : 0f); }
        public void write(String id, float value) { values.put(id, value); }
    }
    @Test public void heldPatOwnsFaceUntilReleaseAndEggCannotBeOverridden() {
        Pose pose = new Pose(); CaicaiHeadPat pat = new CaicaiHeadPat();
        assertTrue(pat.start(true, false, pose));
        for (int i=0;i<600;i++) pat.apply(1f/60, pose);
        assertEquals("held", pat.state()); assertEquals(.15f,pose.current("ParamEyeLOpen"),.001f);
        pat.release(); for(int i=0;i<40;i++) pat.apply(1f/60, pose);
        assertFalse(pat.active());
        assertTrue(pat.start(true, true, pose));
        for (int i=0;i<260;i++) {
            pat.apply(1f/60, pose);
            assertFalse(pat.start(true, false, pose));
            assertFalse(pat.start(false, true, pose));
            pat.release(); assertEquals("easter_egg",pat.state());
        }
        for(int i=0;i<12;i++) pat.apply(1f/60,pose);
        assertFalse(pat.active()); assertTrue(pat.start(true,false,pose));
    }
    @Test public void customRootTiltRateIsBoundedIncludingReversalPauseAndIdleHandoff() {
        CaicaiRootTiltSmoother tilt = new CaicaiRootTiltSmoother();
        assertEquals(25f,CaicaiRootTiltSmoother.DEFAULT_MAX_DEGREES_PER_SECOND,0);
        float previous=0;
        for(int i=0;i<120;i++) {
            float value=tilt.update(i<40 ? 10 : i<80 ? -10 : 0, 1f/60);
            assertTrue(Math.abs(value-previous)<=25f/60+.0001f); previous=value;
        }
        tilt.reset(); assertEquals(1.25f,tilt.update(10,10),.0001f);
        tilt.reset(); tilt.tune(1.5f,1.6f); assertEquals(1f,tilt.update(10,1f/60),.0001f);
        assertEquals(1f,tilt.update(Float.NaN,1f/60),0);
        tilt.reset(); tilt.tune(1,1);
        CaicaiIdleMotion idle=new CaicaiIdleMotion(new Random(17)); Pose pose=new Pose();
        for(int i=0;i<3600;i++) {
            idle.update(1f/60,pose);
            float desired=pose.current("@rootTilt");
            assertEquals("Idle curve remains below the cap",desired,tilt.update(desired,1f/60),.0002f);
        }
    }
}
