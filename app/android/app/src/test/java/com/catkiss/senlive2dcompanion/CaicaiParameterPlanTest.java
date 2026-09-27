package com.catkiss.senlive2dcompanion;

import org.junit.Test;
import static org.junit.Assert.*;

public class CaicaiParameterPlanTest {
    @Test public void planReturnsToLiveIdleAndCannotOwnAudioOrBreath() throws Exception {
        CaicaiParameterPlan plan = new CaicaiParameterPlan();
        plan.start("[{\"time\":0,\"duration\":0.2,\"parameters\":{\"ParamAngleX3\":10,\"ParamMouthOpenY\":1,\"ParamBreath\":1}}]");
        final float[] value = {0};
        final int[] writes = {0};
        CaicaiParameterPlan.Target target = new CaicaiParameterPlan.Target() {
            public boolean accepts(String id) { return true; }
            public float current(String id) { return 2f; }
            public void write(String id, float v) { assertEquals("ParamAngleX3", id); value[0] = v; writes[0]++; }
        };
        plan.apply(.1f, target);
        assertTrue(value[0] > 2f);
        for (int i = 0; i < 15; i++) plan.apply(.1f, target);
        assertEquals(2f, value[0], .02f);
        int finished = writes[0]; plan.apply(.1f, target);
        assertEquals(finished, writes[0]);
    }
    @Test public void clearingPlanImmediatelyRelinquishesAllChannels() throws Exception {
        CaicaiParameterPlan plan = new CaicaiParameterPlan();
        plan.start("[{\"time\":0,\"duration\":1,\"parameters\":{\"OUT\":1}}]");
        plan.clear();
        plan.apply(.1f, new CaicaiParameterPlan.Target() {
            public boolean accepts(String id) { fail(); return false; }
            public float current(String id) { fail(); return 0; }
            public void write(String id, float value) { fail(); }
        });
    }
}
