package com.catkiss.senlive2dcompanion;

import org.junit.Test;
import java.util.*;
import static org.junit.Assert.*;

public class DeepseekLayeredTest {
    private static final class Pose implements DeepseekParameterPlan.Target {
        final Map<String,Float> values=new HashMap<>();
        public boolean accepts(String id) {return true;}
        public float current(String id) {return values.getOrDefault(id,id.endsWith("Open")?1f:0f);}
        public void write(String id,float value) {values.put(id,value);}
    }
    @Test public void circleSweatBlushKeepBrowsMouthAndNaturalBlink() {
        DeepseekExpressions e=new DeepseekExpressions();Pose p=new Pose();
        e.emotion("flustered");e.trigger("圈圈眼","",Arrays.asList("流冷汗","脸红"),"");
        DeepseekBlink blink=new DeepseekBlink(new Random(1) { @Override public float nextFloat() {return 0;} });boolean blinked=false;
        for(int i=0;i<245;i++) {
            e.apply(1f/60,false,p);float opening=p.current("ParamEyeLOpen");
            blink.update(1f/60,e.reservedEyeMask(),p);e.overlay(p);
            blinked|=p.current("ParamEyeLOpen")<opening*.5f;
            assertTrue(p.current("key3")>0);assertTrue(p.current("key13")>0);assertTrue(p.current("key7")>0);
        }
        assertTrue(blinked);assertTrue(p.current("ParamBrowLY")>.8f);
        assertTrue(p.current("ParamMouthOpenY")>.2f);assertEquals(0,e.reservedEyeMask());
    }
    @Test public void heartWinkTearsShadeAndBlushComposeWithoutErasingTheOtherEye() {
        DeepseekExpressions e=new DeepseekExpressions();Pose p=new Pose();
        e.trigger("爱心眼","右wink",Arrays.asList("落泪","黑脸","脸红"),"");
        e.apply(.5f,false,p);e.overlay(p);
        assertTrue(p.current("key4")>.9f);assertTrue(p.current("key2")>.9f);
        assertTrue(p.current("key1")>.9f);assertTrue(p.current("key7")>.9f);
        assertTrue(p.current("ParamEyeROpen")<.01f);assertEquals(1,p.current("ParamEyeLOpen"),.001f);
        assertEquals(2,e.reservedEyeMask());
    }
    @Test public void tongueWinkSuppressesOnlyRabbitTeethAndReportsWhy() {
        DeepseekExpressions e=new DeepseekExpressions();Pose p=new Pose();
        e.trigger("><眼","吐舌wink",Arrays.asList("兔牙","流冷汗","加载","黑脸"),"");
        e.apply(.5f,false,p);e.overlay(p);
        assertEquals(0,p.current("key9"),0);assertTrue(p.current("key5")>.9f);
        assertTrue(p.current("key13")>.9f);assertTrue(p.current("key8")>.9f);
        assertEquals(1,p.current("TongueOut"),0);assertTrue(e.trace().contains("rabbit_teeth/tongue_wink"));
    }
    @Test public void comicUsesTemporaryGlassesAndRestoresLatestManualAppearance() {
        DeepseekExpressions e=new DeepseekExpressions();Pose p=new Pose();
        e.trigger("","",Collections.emptyList(),"装懂小老师");e.apply(.5f,false,p);
        p.write("key11",0);e.overlay(p);e.accessory(p);
        assertTrue(p.current("key11")>.9f);assertTrue(p.current("key9")>.9f);
        assertTrue(p.current("ParamMouthForm")>.8f);
        e.release();for(int i=0;i<30;i++) e.apply(.1f,false,p);
        for(float saved:new float[]{0,1}) {p.write("key11",saved);e.accessory(p);assertEquals(saved,p.current("key11"),0);}
        e.trigger("","",Collections.emptyList(),"装懂小老师");e.clearTransient();
        p.write("key11",0);e.accessory(p);assertEquals(0,p.current("key11"),0);
    }
    @Test public void pcmPreservesExpressionAndClosesSilentPhonemesBeforeAndAfterPhysics() {
        Pose p=new Pose();p.write("ParamMouthForm",.85f);p.write("MouthX",.7f);p.write("MouthPuckerWiden",.4f);
        p.write("key6",1);p.write("JawOpen",1);DeepseekSpeechMouth.apply(.4f,p);
        assertEquals(.48f,p.current("ParamMouthOpenY"),.0001f);assertEquals(.85f,p.current("ParamMouthForm"),0);
        assertEquals(.7f,p.current("MouthX"),0);assertEquals(.4f,p.current("MouthPuckerWiden"),0);
        assertEquals(0,p.current("key6"),0);assertEquals(0,p.current("JawOpen"),0);
        DeepseekSpeechMouth mouth=new DeepseekSpeechMouth();mouth.capture(p);
        p.write("ParamMouthForm",0);p.write("MouthX",0);mouth.restore(p);
        assertEquals(.85f,p.current("ParamMouthForm"),0);assertEquals(.7f,p.current("MouthX"),0);
        p.write("ParamMouthOpenY",.7f);DeepseekSpeechMouth.apply(0,p);
        assertEquals(0,p.current("ParamMouthOpenY"),0);
        assertEquals(1,DeepseekSpeechMouth.opening(1),0);assertEquals(0,DeepseekSpeechMouth.opening(Float.NaN),0);
    }
    @Test public void sustainedPostureSurvivesNextBeatAndHoldsAfterFullArrival() throws Exception {
        Pose p=new Pose();DeepseekPosture posture=new DeepseekPosture();DeepseekParameterPlan plan=new DeepseekParameterPlan();
        posture.request("1:0",0);float full=0;boolean returned=false;
        for(int i=0;i<330;i++) {
            if(i==50 || i==100) plan.replace("[{\"time\":0,\"duration\":0.4,\"parameters\":{\"AngleZ\":10}}]",p);
            p.values.clear();plan.apply(1f/60,p);posture.apply(1f/60,p);
            float value=p.current("LeanInput");
            if(i==29) assertTrue(value< -10 && value> -20);
            if(value==-30) full+=1f/60;
            if(i>215 && value>-30) returned=true;
            if(i==70) assertTrue(p.current("AngleZ")>0);
            assertTrue(value>=-30 && value<=0);
        }
        assertTrue(full>=2.49f);assertTrue(returned);assertFalse(posture.active());
        posture.request("1:0",0);assertFalse(posture.active()); // Heartbeat cannot restart it.
        posture.request("2:0",0);assertTrue(posture.active());posture.clear();assertFalse(posture.active());
    }
    @Test public void delayedLeanAndAudioStopCannotLeaveAPendingOrStuckPose() {
        DeepseekPosture posture=new DeepseekPosture();Pose p=new Pose();posture.request("opening",1);
        for(int i=0;i<30;i++) posture.apply(1f/60,p);assertEquals(0,p.current("LeanInput"),0);
        posture.release();assertFalse(posture.active());
        posture.request("speech",0);for(int i=0;i<120;i++) posture.apply(1f/60,p);
        posture.release();for(int i=0;i<80;i++) posture.apply(1f/60,p);
        assertEquals(0,p.current("LeanInput"),0);assertFalse(posture.active());
    }
    @Test public void heldSemanticBodyStillMovesAndIdleUsesTheWiderAuthoredRange() throws Exception {
        Pose p=new Pose();DeepseekIdleMotion idle=new DeepseekIdleMotion(new Random(31));
        DeepseekParameterPlan plan=new DeepseekParameterPlan();
        plan.start("[{\"time\":0,\"duration\":4,\"parameters\":{\"PositionY\":10}}]");
        float low=100,high=-100,idleLow=100,idleHigh=-100;
        for(int i=0;i<900;i++) {
            idle.update(1f/60,p);float y=p.current("PositionY");idleLow=Math.min(idleLow,y);idleHigh=Math.max(idleHigh,y);
            if(i<220) {plan.apply(1f/60,p);if(i>80) {low=Math.min(low,p.current("PositionY"));high=Math.max(high,p.current("PositionY"));}}
            for(String axis:Arrays.asList("PositionX","PositionY","PositionZ")) assertTrue(Math.abs(p.current(axis))<=30);
        }
        assertTrue(high-low>1);assertTrue(idleHigh-idleLow>25);
    }
}
