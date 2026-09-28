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
    @Test public void rootHasBoundedSeparateNamespaceAndReturnsToIdle() throws Exception {
        CaicaiParameterPlan plan=new CaicaiParameterPlan();
        plan.start("[{\"time\":0,\"duration\":0.2,\"parameters\":{\"@rootX\":99},\"root\":{\"x\":5,\"tilt\":90}}]");
        final java.util.Map<String,Float> values=new java.util.HashMap<>();
        CaicaiParameterPlan.Target out=new CaicaiParameterPlan.Target() {
            public boolean accepts(String id) { return true; }
            public float current(String id) { return 0; }
            public void write(String id,float v) { values.put(id,v); }
        };
        plan.apply(.1f,out);
        assertTrue(values.get("@rootX")>0 && values.get("@rootX")<=.15f);
        assertTrue(values.get("@rootTilt")>0 && values.get("@rootTilt")<=10);
        assertFalse(CaicaiParameterPlan.supports("@rootX"));
        for(int i=0;i<15;i++) plan.apply(.1f,out);
        assertEquals(0,values.get("@rootX"),.001f);
        assertEquals(0,values.get("@rootTilt"),.001f);
    }

}
