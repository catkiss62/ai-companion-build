package com.catkiss.senlive2dcompanion;

import java.util.*;
import org.junit.Test;
import static org.junit.Assert.*;

public class DeepseekMouthRollbackTest {
    private static final class Pose implements DeepseekParameterPlan.Target {
        final Map<String,Float> values=new HashMap<>();
        public boolean accepts(String id) {return true;}
        public float current(String id) {return values.getOrDefault(id,0f);}
        public void write(String id,float value) {values.put(id,value);}
    }
    @Test public void playfulRestoresClosedGrinWithoutChangingItsBrowsOrOtherEmotions() {
        Map<String,Float> p=DeepseekExpressions.emotionPose("playful");
        for(String id:new String[]{"ParamMouthOpenY","MouthFunnel","MouthPuckerWiden","Mouthpucker","JawOpen","TongueOut"})
            assertEquals(id,0,p.get(id),0);
        assertEquals(1,p.get("ParamMouthForm"),0);assertEquals(.8f,p.get("MouthX"),0);
        assertEquals(-.25f,p.get("ParamBrowLY"),0);assertEquals(.55f,p.get("ParamBrowRY"),0);
        assertEquals(.9f,p.get("REyeSquint"),0);assertEquals(.6f,p.get("LEyeSquint"),0);
        assertEquals(1,p.get("ParamEyeLOpen"),0);assertEquals(1,p.get("ParamEyeROpen"),0);
        assertTrue(DeepseekExpressions.emotionPose("happy").get("ParamMouthOpenY")>0);
        assertTrue(DeepseekExpressions.emotionPose("excited").get("ParamMouthOpenY")>.5f);
    }
    @Test public void speechUsesRigDefaultBeforeAndAfterPhysicsWhileKeepingTheSmile() {
        Pose p=new Pose();p.values.putAll(DeepseekExpressions.emotionPose("playful"));
        p.write("MouthPuckerWiden",.45f);p.write("CheeckPuff",.3f);
        DeepseekSpeechMouth mouth=new DeepseekSpeechMouth();mouth.capture(p);
        DeepseekSpeechMouth.apply(.4f,p,-.12f);
        assertEquals(-.12f,p.current("MouthX"),0);assertEquals(.48f,p.current("ParamMouthOpenY"),.00001f);
        p.write("MouthX",.95f);p.write("ParamMouthForm",0);p.write("MouthPuckerWiden",0);
        mouth.restore(p);DeepseekSpeechMouth.apply(.4f,p,-.12f);
        assertEquals(-.12f,p.current("MouthX"),0);assertEquals(1,p.current("ParamMouthForm"),0);
        assertEquals(.45f,p.current("MouthPuckerWiden"),0);assertEquals(.3f,p.current("CheeckPuff"),0);
        assertEquals(.48f,p.current("ParamMouthOpenY"),.00001f);
    }
    @Test public void silenceCentersAndClosesButSpeechReleaseRetainsTheStaticExpression() {
        Pose p=new Pose();p.values.putAll(DeepseekExpressions.emotionPose("playful"));
        p.write("MouthFunnel",.8f);p.write("JawOpen",1);p.write("key6",1);
        DeepseekSpeechMouth.apply(0,p);
        for(String id:new String[]{"MouthX","ParamMouthOpenY","MouthFunnel","JawOpen","key6"})
            assertEquals(id,0,p.current(id),0);
        assertEquals(1,p.current("ParamMouthForm"),0);
        // Normal expression ownership resumes when real audio no longer owns the mouth.
        p.values.putAll(DeepseekExpressions.emotionPose("playful"));
        assertEquals(.8f,p.current("MouthX"),0);assertEquals(0,p.current("ParamMouthOpenY"),0);
    }
    @Test public void invalidInputsCannotMoveTheMouthAndAudioGainStillClamps() {
        Pose p=new Pose();DeepseekSpeechMouth.apply(Float.NaN,p,Float.NaN);
        assertEquals(0,p.current("MouthX"),0);assertEquals(0,p.current("ParamMouthOpenY"),0);
        DeepseekSpeechMouth.apply(1,p,Float.POSITIVE_INFINITY);
        assertEquals(0,p.current("MouthX"),0);assertEquals(1,p.current("ParamMouthOpenY"),0);
        DeepseekSpeechMouth.apply(-1,p);assertEquals(0,p.current("ParamMouthOpenY"),0);
    }
}
