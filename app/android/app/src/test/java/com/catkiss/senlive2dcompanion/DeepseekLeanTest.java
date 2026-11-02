package com.catkiss.senlive2dcompanion;
import org.junit.Test;
import static org.junit.Assert.*;
import java.util.*;

public class DeepseekLeanTest {
    private static final class Pose implements DeepseekParameterPlan.Target {
        final Map<String,Float> values=new HashMap<>();
        public boolean accepts(String id) {return true;}
        public float current(String id) {return values.getOrDefault(id,0f);}
        public void write(String id,float v) {values.put(id,v);}
        void frame(float lean) {
            values.clear();write("LeanInput",lean);write("AngleX",27);write("AngleY",-26);
            write("AngleZ",18);write("ParamEyeBallX",.8f);write("ParamEyeBallY",-.7f);
            write("ParamEyeLOpen",.2f);write("ParamMouthOpenY",.6f);
        }
    }
    @Test public void leanLooksAheadAfterPointerWithoutOwningBlinkRollOrPcm() {
        DeepseekLeanFocus focus=new DeepseekLeanFocus();Pose p=new Pose();
        for(int i=0;i<60;i++) {p.frame(-30);focus.apply(1f/60,p,false);}
        assertTrue(Math.abs(p.current("ParamEyeBallX"))<.001f);assertTrue(Math.abs(p.current("ParamEyeBallY"))<.001f);
        assertTrue(Math.abs(p.current("AngleX"))<5.5f);assertTrue(Math.abs(p.current("AngleY"))<5.3f);
        assertEquals(18,p.current("AngleZ"),0);assertEquals(.2f,p.current("ParamEyeLOpen"),0);
        assertEquals(.6f,p.current("ParamMouthOpenY"),0);
    }
    @Test public void followReturnsSmoothlyAndPatOrManualPreviewKeepPriority() {
        DeepseekLeanFocus focus=new DeepseekLeanFocus();Pose p=new Pose();
        p.frame(0);focus.apply(1f/60,p,false);assertEquals(.8f,p.current("ParamEyeBallX"),0);
        for(int i=0;i<60;i++) {p.frame(-30);focus.apply(1f/60,p,false);}
        p.frame(0);focus.apply(1f/60,p,false);assertTrue(p.current("ParamEyeBallX")<.2f);
        for(int i=0;i<60;i++) {p.frame(0);focus.apply(1f/60,p,false);}
        assertEquals(.8f,p.current("ParamEyeBallX"),.001f);assertEquals(27,p.current("AngleX"),.01f);
        p.frame(-30);focus.apply(.1f,p,true);assertEquals(.8f,p.current("ParamEyeBallX"),0);
    }
    @Test public void slowerLeanReachesFullTargetAndCompletesReturnWithoutSnap() throws Exception {
        DeepseekParameterPlan plan=new DeepseekParameterPlan();Pose p=new Pose();
        plan.start("[{\"time\":0,\"duration\":1.3,\"parameters\":{\"LeanInput\":-30}}]");
        for(int i=0;i<12;i++) {p.values.clear();plan.apply(1f/60,p);}
        assertTrue(p.current("LeanInput")>-24);assertTrue(p.current("LeanInput")<-20);
        for(int i=0;i<60;i++) {p.values.clear();plan.apply(1f/60,p);}
        assertEquals(-30,p.current("LeanInput"),0);plan.release();
        for(int i=0;i<12;i++) {p.values.clear();plan.apply(1f/60,p);}
        assertTrue(p.current("LeanInput")<-9);assertTrue(p.current("LeanInput")>-11);
        float old=p.current("LeanInput");
        for(int i=0;i<75;i++) {
            p.values.clear();plan.apply(1f/60,p);float current=p.current("LeanInput");
            assertTrue(current>=old-.0001f);assertTrue(current-old<1.01f);old=current;
        }
        assertEquals(0,p.current("LeanInput"),0);assertFalse(plan.active());
    }
}
