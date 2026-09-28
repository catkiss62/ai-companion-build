package com.catkiss.senlive2dcompanion;

import org.junit.Test;
import java.util.*;
import static org.junit.Assert.*;

public class CaicaiPerformanceTest {
    private static class Pose implements CaicaiParameterPlan.Target {
        final Map<String,Float> values=new HashMap<>();
        public boolean accepts(String id) { return CaicaiParameterPlan.supports(id) || id.startsWith("@root"); }
        public float current(String id) { return values.getOrDefault(id,0f); }
        public void write(String id,float value) { assertTrue(Float.isFinite(value)); values.put(id,value); }
    }
    @Test public void idleUsesVisibleAxesAndKeepsMovingAcrossPhraseBoundaries() {
        CaicaiIdleMotion idle=new CaicaiIdleMotion(new Random(71)); Pose pose=new Pose();
        Map<String,Float> lo=new HashMap<>(),hi=new HashMap<>();
        float previous=0;
        for(int i=0;i<1800;i++) {
            pose.values.clear(); idle.update(1f/30,pose);
            for(Map.Entry<String,Float> e:pose.values.entrySet()) {
                lo.merge(e.getKey(),e.getValue(),Math::min); hi.merge(e.getKey(),e.getValue(),Math::max);
            }
            float x=pose.current("ParamAngleX3");
            if(i>0) assertTrue("no pulse discontinuity",Math.abs(x-previous)<4);
            previous=x;
        }
        assertTrue(hi.get("ParamAngleX3")-lo.get("ParamAngleX3")>40);
        assertTrue(hi.get("ParamAngleY2")-lo.get("ParamAngleY2")>30);
        for(String id:new String[]{"ParamBodyAngleX","ParamBodyAngleY","ParamBodyAngleZ"})
            assertTrue(id,hi.get(id)-lo.get(id)>7);
        assertTrue(hi.get("@rootX")-lo.get("@rootX")>.12f);
        assertTrue(hi.get("@rootTilt")-lo.get("@rootTilt")>8f);
        assertFalse(pose.values.containsKey("ParamAngleX"));
        assertFalse(pose.values.containsKey("ParamMouthOpenY"));
        assertFalse(pose.values.containsKey("ParamBreath"));
    }
    @Test public void attentionOverridesConversationThenReleasesToIdle() {
        CaicaiIdleMotion idle=new CaicaiIdleMotion(new Random(71)); Pose pose=new Pose();
        idle.look(true,1,-1);
        for(int i=0;i<20;i++) { idle.update(1f/30,pose); pose.write("ParamAngleX3",-20); idle.applyAttention(pose); }
        assertTrue(pose.current("ParamAngleX3")>18);
        assertTrue(pose.current("ParamEyeBallY")<-.7);
        for(int i=0;i<100;i++) idle.update(1f/30,pose);
        pose.write("ParamAngleX3",-20); idle.applyAttention(pose);
        assertEquals(-20,pose.current("ParamAngleX3"),.001);
    }
    @Test public void patLeaseClearsAttentionSoHeadPlanSurvives() {
        CaicaiIdleMotion idle=new CaicaiIdleMotion(new Random(71)); Pose pose=new Pose();
        idle.look(true,1,1); idle.update(.1f,pose); idle.clearAttention();
        pose.write("ParamAngleY2",-25); idle.applyAttention(pose);
        assertEquals(-25,pose.current("ParamAngleY2"),.001f);
    }
    @Test public void maidExpressionsAreVisibleWithoutStealingLipSync() {
        CaicaiFaceMotion face=new CaicaiFaceMotion(); Pose pose=new Pose();
        for(int i=0;i<30;i++) { pose.values.clear(); face.update("confused",1f/30,pose); }
        assertTrue(pose.current("MOUTHX")>.8);
        assertTrue(pose.current("ParamBrowRY")-pose.current("ParamBrowLY")>1.3);
        assertFalse(pose.values.containsKey("ParamMouthOpenY"));
        assertFalse(pose.values.containsKey("OUT"));
        for(int i=0;i<40;i++) { pose.values.clear(); face.update("normal",1f/30,pose); }
        assertEquals(0,pose.current("MOUTHX"),.01);
    }
}
