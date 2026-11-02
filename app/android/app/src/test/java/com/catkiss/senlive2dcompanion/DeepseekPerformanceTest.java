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
        assertTrue(p.current("AngleX")<=30);assertTrue(p.current("PositionX")<=30);
        assertTrue(p.current("@rootX")<=.15f);assertTrue(p.current("@rootTilt")<=10);
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

    @Test public void winkHasReadableHoldAndSmoothEntryExitWithoutChangingAnatomicalEye() {
        assertEquals(0,DeepseekExpressions.winkClosure(0,false),0);
        assertEquals(.5f,DeepseekExpressions.winkClosure(.09f,false),.001f);
        assertEquals(1,DeepseekExpressions.winkClosure(.5f,false),0);
        assertEquals(1,DeepseekExpressions.winkClosure(.8f,false),0);
        assertEquals(.5f,DeepseekExpressions.winkClosure(1.02f,false),.001f);
        assertEquals(0,DeepseekExpressions.winkClosure(1.2f,false),0);
        assertEquals(1,DeepseekExpressions.winkClosure(1.2f,true),0);
        assertEquals(0,DeepseekExpressions.winkClosure(1.6f,true),0);
        for(String wink:Arrays.asList("左wink","右wink","吐舌wink")) {
            DeepseekExpressions e=new DeepseekExpressions();Pose p=new Pose();
            e.trigger("",wink,"");e.apply(.6f,false,p);e.overlay(p);
            String closed=wink.equals("右wink")?"ParamEyeROpen":"ParamEyeLOpen";
            String other=wink.equals("右wink")?"ParamEyeLOpen":"ParamEyeROpen";
            assertTrue(p.current(closed)<.01f);assertEquals(1,p.current(other),.001f);
            assertEquals(wink.equals("吐舌wink")?1:0,p.current("TongueOut"),0);
        }
    }

    @Test public void smallFormReverseSmileSettlesNearFullDownturnAndNormalCanRecover() {
        DeepseekExpressions e=new DeepseekExpressions();Pose p=new Pose();
        for(int i=0;i<30;i++) e.apply(.1f,true,p);
        assertTrue(p.current("ParamMouthForm")<-.99f);
        for(int i=0;i<30;i++) e.apply(.1f,false,p);
        assertEquals(0,p.current("ParamMouthForm"),.001f);
    }


    @Test public void plannedHeadAndRootSurviveBothParsingAndExecutionAndLeanUsesFullRange() throws Exception {
        DeepseekParameterPlan plan=new DeepseekParameterPlan();Pose p=new Pose();
        plan.start("[{\"time\":0,\"duration\":2,\"parameters\":{\"AngleX\":25,\"PositionZ\":20,\"LeanInput\":-30},\"root\":{\"x\":0.075,\"tilt\":6}}]");
        plan.setGain(1.5f);
        for(int i=0;i<110;i++) {p.values.clear();plan.apply(1f/60,p);}
        assertTrue(p.current("AngleX")>29);assertTrue(p.current("PositionZ")>20);
        assertTrue(p.current("@rootX")>.07f);assertTrue(p.current("@rootTilt")>8);
        assertTrue(p.current("LeanInput")<-28.5f); // Full -30 target is never multiplied down by gain.
        plan.release();for(int i=0;i<45;i++) {p.values.clear();plan.apply(1f/60,p);}
        assertEquals(0,p.current("LeanInput"),.01f);
    }
    @Test public void emotionsUseTheActualFaceRangeAndRecoverNeutralWithoutLeavingButtonsOrMouthOpening() {
        assertEquals(1,DeepseekExpressions.emotionPose("happy").get("ParamMouthForm"),0);
        assertTrue(DeepseekExpressions.emotionPose("happy").get("REyeSquint")>.8f);
        assertEquals(-1,DeepseekExpressions.emotionPose("angry").get("ParamBrowLY"),0);
        assertEquals(1.5f,DeepseekExpressions.emotionPose("surprised").get("ParamEyeLOpen"),0);
        assertTrue(DeepseekExpressions.emotionPose("confused").get("ParamBrowLY")-
            DeepseekExpressions.emotionPose("confused").get("ParamBrowRY")>1.4f);
        DeepseekExpressions e=new DeepseekExpressions();Pose p=new Pose();
        for(String emotion:Arrays.asList("happy","excited","affection","shy","flustered","tense","worried","helpless","afraid","angry","sad","disgust","serious","surprised","confident","playful","ashamed","calm","confused","normal")) {
            e.emotion(emotion);for(int i=0;i<100;i++) e.apply(1f/60,false,p);
            for(Map.Entry<String,Float> item:p.values.entrySet()) {
                float v=item.getValue();assertTrue(item.toString(),Float.isFinite(v));
                assertTrue(item.toString(),v>=-1 && v<=(item.getKey().endsWith("Open")?1.5f:1));
                assertFalse(item.getKey().startsWith("key"));assertFalse(item.getKey().equals("ParamMouthOpenY"));
            }
        }
        assertEquals(0,p.current("ParamMouthForm"),.001f);assertEquals(0,p.current("EyeSmile"),.001f);
        assertEquals(1,p.current("ParamEyeLOpen"),.001f);
    }
}
