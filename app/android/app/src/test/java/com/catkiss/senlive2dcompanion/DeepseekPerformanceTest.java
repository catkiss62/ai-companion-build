package com.catkiss.senlive2dcompanion;

import java.util.*;
import org.junit.Test;
import org.json.JSONException;
import static org.junit.Assert.*;

public class DeepseekPerformanceTest {
    private static DeepseekMotionClip clip(String segments) throws Exception {
        return new DeepseekMotionClip("{\"Meta\":{\"Duration\":1,\"Loop\":true},\"Curves\":[{\"Target\":\"Parameter\",\"Id\":\"Movement1\",\"Segments\":"+segments+"}]}",DeepseekGestures.CHANNELS);
    }
    private static final class Pose implements DeepseekParameterPlan.Target {
        final Map<String,Float> values=new HashMap<>();
        public boolean accepts(String id) {return true;}
        public float current(String id) {return values.getOrDefault(id,id.endsWith("Open")?1f:0f);}
        public void write(String id,float value) {values.put(id,value);}
    }
    @Test public void authoredCurvesSupportAllFourSegmentKindsAndHoldEndpoints() throws Exception {
        assertEquals(.5f,clip("[0,0,0,1,1]").sample(.5f).get("Movement1"),.001f);
        assertEquals(0,clip("[0,0,2,1,1]").sample(.5f).get("Movement1"),0);
        assertEquals(1,clip("[0,0,3,1,1]").sample(.5f).get("Movement1"),0);
        assertEquals(1,clip("[0,0,2,1,1]").sample(1).get("Movement1"),0);
        assertEquals(1,clip("[0,0,3,1,1]").sample(0).get("Movement1"),0);
        DeepseekMotionClip bezier=clip("[0,0,1,0.2,0,0.8,1,1,1]");
        assertEquals(.5f,bezier.sample(.5f).get("Movement1"),.001f);
        assertEquals(1,bezier.sample(10).get("Movement1"),0);
    }
    @Test(expected=JSONException.class) public void malformedCurveFailsClosed() throws Exception {clip("[0,0,1,0.2,0]");}
    @Test public void curveCannotImportClothesOrMouthIntoArmOwner() throws Exception {
        DeepseekMotionClip c=new DeepseekMotionClip("{\"Meta\":{\"Duration\":1},\"Curves\":[{\"Target\":\"Parameter\",\"Id\":\"Clothes2\",\"Segments\":[0,0,0,1,1]}]}",DeepseekGestures.CHANNELS);
        assertTrue(c.sample(.5f).isEmpty());
    }
    @Test public void interruptedGestureReturnsBeforeNextAndNeverLoopsAnEnterClip() throws Exception {
        DeepseekGestures g=new DeepseekGestures();
        g.register("grass",clip("[0,0,0,1,1]"),clip("[0,1,0,1,0]"));
        g.register("finger",clip("[0,0,0,1,1]"),clip("[0,1,0,1,0]"));
        assertTrue(g.request("grass",.4f));
        float old=g.update(.4f).get("Movement1");
        g.request("finger",.4f);
        float next=g.update(.001f).get("Movement1");
        assertEquals(old,next,.001f);
        assertTrue(g.trace().contains("grass:exit"));
        for(int i=0;i<12;i++) g.update(.1f);
        assertTrue(g.trace().contains("finger:enter"));
        g.stop();
        for(int i=0;i<20;i++) g.update(.1f);
        assertTrue(g.trace().startsWith(":idle"));
        assertFalse(g.request("unknown",1));
    }
    @Test public void specialEyesAreExclusiveAndSuppressWinkButPermitBlush() {
        DeepseekExpressions e=new DeepseekExpressions();Pose p=new Pose();
        e.trigger("爱心眼","吐舌wink","脸红");e.apply(.2f,false,p);e.overlay(p);
        assertTrue(p.current("key4")>.5f);assertTrue(p.current("key7")>.5f);
        for(String id:Arrays.asList("key3","key5","key6")) assertEquals(0,p.current(id),0);
        assertEquals(0,p.current("TongueOut"),0);assertEquals(1,p.current("ParamEyeLOpen"),.001f);
        e.trigger("圈圈眼","","");e.apply(.2f,false,p);e.overlay(p);
        assertEquals(0,p.current("key4"),0);assertTrue(p.current("key3")>.5f);
        e.release();for(int i=0;i<20;i++) {e.apply(.1f,false,p);e.overlay(p);}
        assertTrue(p.current("key3")<.001f);
    }
    @Test public void smallFormIsUnhappyAndEveryEmotionHasIndependentFacialPose() {
        DeepseekExpressions e=new DeepseekExpressions();Pose p=new Pose();
        for(int i=0;i<20;i++) e.apply(.1f,true,p);
        assertTrue(p.current("ParamMouthForm")<-.7f);assertTrue(p.current("ParamBrowLY")<-.45f);
        p.write("ParamMouthForm",1);e.smallReaction(p);assertTrue(p.current("ParamMouthForm")<-.7f);
        Set<Map<String,Float>> distinct=new HashSet<>();
        for(String emotion:Arrays.asList("happy","excited","affection","shy","flustered","tense","worried","helpless","afraid","angry","sad","disgust","serious","surprised","confident","playful","ashamed","calm","confused")) {
            Map<String,Float> pose=DeepseekExpressions.emotionPose(emotion);distinct.add(pose);
            assertFalse(pose.containsKey("ParamMouthOpenY"));
            assertFalse(pose.containsKey("key4")); // Heart eyes need a semantic opt-in.
        }
        assertEquals(19,distinct.size());
    }
    @Test public void parameterPlanRejectsAudioOutfitsPhysicsAndEnforcesSafeRigBudget() throws Exception {
        DeepseekParameterPlan plan=new DeepseekParameterPlan();Pose p=new Pose();
        plan.start("[{\"time\":0,\"duration\":0.2,\"parameters\":{\"AngleX\":99,\"PositionX\":99,\"ParamMouthOpenY\":1,\"Clothes2\":1,\"Movement1\":1,\"ParamAngleX\":30},\"root\":{\"x\":5,\"tilt\":90}}]");
        plan.setGain(1.5f);plan.apply(.2f,p);
        assertTrue(p.current("AngleX")<=14);assertTrue(p.current("PositionX")<=8);
        assertTrue(p.current("@rootX")<=.035f);assertTrue(p.current("@rootTilt")<=3);
        for(String id:Arrays.asList("ParamMouthOpenY","Clothes2","Movement1","ParamAngleX")) assertFalse(p.values.containsKey(id));
        for(int i=0;i<30;i++) {p.values.clear();plan.apply(.1f,p);}
        assertTrue(p.values.isEmpty());
    }
    @Test public void releaseSettlesBeforeRelinquishingSlowBodyAndRootChannels() throws Exception {
        DeepseekParameterPlan plan=new DeepseekParameterPlan();Pose p=new Pose();
        plan.start("[{\"time\":0,\"duration\":1,\"parameters\":{\"PositionX\":5},\"root\":{\"x\":0.03}}]");
        plan.apply(.8f,p);float old=p.current("PositionX");assertTrue(old>1);
        plan.release();
        for(int i=0;i<6;i++) {p.values.clear();plan.apply(.1f,p);}
        assertTrue(p.current("PositionX")<.03f);assertTrue(p.current("@rootX")<.001f);
    }

    @Test public void loadingAndSweatUseActualHelperBoundsAndWrapInsteadOfSticking() {
        assertEquals(10,DeepseekExpressions.cycle(.5f,1,0,20),.001f);
        assertEquals(0,DeepseekExpressions.cycle(1,1,0,20),.001f);
        assertEquals(10,DeepseekExpressions.cycle(1.5f,1,0,20),.001f);
        assertEquals(-1,DeepseekExpressions.cycle(Float.NaN,1,-1,1),0);
    }

}
