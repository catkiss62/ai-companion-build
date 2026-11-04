package com.catkiss.senlive2dcompanion;

import androidx.test.ext.junit.runners.AndroidJUnit4;
import java.util.*;
import org.junit.Test;
import org.junit.runner.RunWith;
import static org.junit.Assert.*;

/** Actual production interaction state on Android; no private model is bundled. */
@RunWith(AndroidJUnit4.class)
public class DeepseekStage3SmokeTest {
    @Test public void acousticMouthUsesActualPcmAndReleasesWithoutChangingTheSmileOnAndroid() {
        java.nio.ByteBuffer b=java.nio.ByteBuffer.allocate(1920).order(java.nio.ByteOrder.LITTLE_ENDIAN);
        for(int i=0;i<960;i++) b.putShort((short)(6000*(Math.sin(2*Math.PI*350*i/24000)+.65*Math.sin(2*Math.PI*2500*i/24000))));
        DeepseekAudioMouth.Shape shape=new DeepseekAudioMouth().analyze(b.array(),0,960,24000,1,16,1);
        assertTrue(shape.width>.2f);
        Pose p=new Pose();p.write("ParamMouthForm",1);p.write("MouthPressLipOpen",-1);
        DeepseekSpeechMouth mouth=new DeepseekSpeechMouth();mouth.signal(shape.width,shape.opening,1);
        mouth.advance(.1f,true,2);mouth.capture(p);mouth.applyFrame(.4f,p,0);
        assertTrue(p.current("MouthPuckerWiden")>.1f);assertEquals(0,p.current("MouthX"),0);
        mouth.restore(p);mouth.applyFrame(.4f,p,0);assertEquals(1,p.current("ParamMouthForm"),0);
        mouth.advance(.016f,false,3);p.write("MouthPuckerWiden",0);mouth.applyFrame(0,p,0);
        assertEquals(0,p.current("MouthPuckerWiden"),0);assertEquals(0,p.current("ParamMouthOpenY"),0);
        assertEquals(-1,p.current("MouthPressLipOpen"),0);
    }
    private static final class Pose implements DeepseekParameterPlan.Target {
        final Map<String,Float> values=new HashMap<>();
        public boolean accepts(String id) {return true;}
        public float current(String id) {return values.getOrDefault(id,id.endsWith("Open")?1f:0f);}
        public void write(String id,float value) {values.put(id,value);}
    }
    @Test public void longHeldPatAndProtectedEggReleaseOnAndroid() {
        Pose p=new Pose();DeepseekHeadPat pat=new DeepseekHeadPat();pat.start(true,false,p);
        for(int i=0;i<1200;i++) {p.values.clear();pat.apply(1f/60,true,p);}
        assertEquals("held",pat.state());assertTrue(p.current("ParamMouthForm")<-.6f);
        pat.release();for(int i=0;i<40;i++) {p.values.clear();pat.apply(1f/60,true,p);}
        assertFalse(pat.active());pat.start(true,true,p);
        for(int i=0;i<160;i++) {p.values.clear();pat.apply(1f/60,false,p);assertFalse(pat.start(true,false,p));}
        for(int i=0;i<20;i++) pat.apply(1f/60,false,p);assertFalse(pat.active());
    }
    @Test public void localMovementAndBlinkRemainBoundedAcrossManyIdleAndTouchFrames() {
        Pose p=new Pose();DeepseekIdleMotion idle=new DeepseekIdleMotion(new Random(31));DeepseekBlink blink=new DeepseekBlink(new Random(7));
        idle.tune(1.5f,1.6f);
        for(int i=0;i<18000;i++) {
            p.values.clear();if(i%180==0) idle.look(true,i%360==0?-1:1,.5f);
            idle.update(1f/60,p);idle.applyAttention(p,1);
            assertTrue(Math.abs(p.current("AngleX"))<=30);assertTrue(Math.abs(p.current("@rootTilt"))<=10);
            assertFalse(p.values.containsKey("ParamMouthForm"));
            p.write("ParamEyeLOpen",.8f);p.write("ParamEyeROpen",.8f);blink.update(1f/60,i%120<60,p);
            assertTrue(p.current("ParamEyeLOpen")<=.8f);assertTrue(p.values.size()<20);
        }
        idle.clearAttention();assertFalse(idle.attentive());
    }
    @Test public void cropAndTiltHitSnapshotIsIndependentOfSubsequentMatrixWrites() {
        float[] m={1.2f,.1f,0,0,-.1f,2f,0,0,0,0,1,0,0,-1,0,1};
        DeepseekHitTransform hit=new DeepseekHitTransform(m,-1,1,1,-1);float[] out=new float[2];
        assertTrue(hit.inverse(.5f,1,out));assertEquals(.5f,out[0],.0001f);assertEquals(.5f,out[1],.0001f);
        m[0]=Float.NaN;assertTrue(hit.inverse(.5f,1,out));
        assertFalse(DeepseekHitTransform.INVALID.inverse(.5f,.5f,out));
    }

    @Test public void leaningAndExpressiveHeadSurviveTheProductionPlanOnAndroid() throws Exception {
        Pose p=new Pose();DeepseekParameterPlan plan=new DeepseekParameterPlan();
        plan.start("[{\"time\":0,\"duration\":1,\"parameters\":{\"AngleX\":25,\"LeanInput\":-30},\"root\":{\"tilt\":6}}]");
        for(int i=0;i<60;i++) {p.values.clear();plan.apply(1f/60,p);}
        assertTrue(p.current("AngleX")>23);assertTrue(p.current("LeanInput")<-28);
        assertTrue(p.current("@rootTilt")>5.5f);
        plan.release();for(int i=0;i<80;i++) {p.values.clear();plan.apply(1f/60,p);}
        assertTrue(Math.abs(p.current("LeanInput"))<.01f);
    }

    @Test public void headAnchoredSmallFormUsesMorphedLegPivotOnAndroid() {
        DeepseekLegPivot.Bounds whole=new DeepseekLegPivot.Bounds(-1,1,1,-3);
        DeepseekLegPivot.Bounds legs=new DeepseekLegPivot.Bounds(-.4f,.4f,-1,-3);
        DeepseekLegPivot.Bounds smallLegs=new DeepseekLegPivot.Bounds(-.08f,.08f,.44f,.04f);
        float[] p=DeepseekLegPivot.map(whole,legs,smallLegs,.88f);assertEquals(.136f,p[1],.00001f);
        for(float angle:new float[]{-10,10}) {
            float[] m=DeepseekLegPivot.matrix(1280,2204,p[0],p[1],p[2],0,angle);
            assertEquals(p[0],m[0]*p[0]+m[4]*p[1]+m[12],.00001f);
            assertEquals(p[1],m[1]*p[0]+m[5]*p[1]+m[13],.00001f);
        }
        Pose pose=new Pose();DeepseekLeanFocus focus=new DeepseekLeanFocus();
        for(int i=0;i<60;i++) {pose.write("LeanInput",-30);pose.write("ParamEyeBallX",.8f);focus.apply(1f/60,pose,false);}
        assertTrue(Math.abs(pose.current("ParamEyeBallX"))<.001f);
    }
    @Test public void actualViewportGazeAndHalfDisgustRunOnAndroid() {
        DeepseekGaze gaze=new DeepseekGaze();
        float[] m={1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1};
        gaze.capture(m,new DeepseekLegPivot.Bounds(-.2f,.2f,.5f,.3f),1000,1800);
        assertArrayEquals(new float[]{.8f,-1},gaze.direction(.8f,-.9f),.00001f);
        float[] point=Live2DTouchCoordinates.stage(940,1700,10,200,1000,1600);
        assertArrayEquals(new float[]{.86f,-.875f},point,.00001f);
        Pose p=new Pose();DeepseekExpressions expressions=new DeepseekExpressions();
        for(int i=0;i<60;i++) expressions.apply(.05f,true,p);
        assertEquals(.775f,p.current("ParamEyeLOpen"),.001f);
        DeepseekFootProbe probe=new DeepseekFootProbe();float[] original=m.clone();
        probe.capture(m,m,m,new DeepseekLegPivot.Bounds(-.2f,.2f,-.2f,-.5f),0,-.3f,0);
        assertArrayEquals(original,m,0);assertTrue(probe.trace().contains("visible_leg_bounds_lower"));
    }

    @Test public void smallAxisMovesToLowerLegWithoutChangingTravelOnAndroid() {
        DeepseekLegPivot.Bounds legs=new DeepseekLegPivot.Bounds(-.08f,.08f,.44f,.04f);
        float[] mapped=DeepseekLegPivot.map(new DeepseekLegPivot.Bounds(-1,1,1,-3),
            new DeepseekLegPivot.Bounds(-.4f,.4f,-1,-3),legs,.88f);
        float[] lower=DeepseekLegPivot.withSmallFormAnchor(mapped,legs,.88f,.55f);
        assertEquals(.064f,lower[1],.00001f);assertEquals(mapped[2],lower[2],0);
        for(float angle:new float[]{-10,10}) {
            float[] root=DeepseekLegPivot.matrix(1280,2204,lower[0],lower[1],lower[2],.1f,angle);
            assertEquals(lower[0]+lower[2]*.1f,root[0]*lower[0]+root[4]*lower[1]+root[12],.00001f);
            assertEquals(lower[1],root[1]*lower[0]+root[5]*lower[1]+root[13],.00001f);
        }
    }

    @Test public void layeredExpressionAudioAndIndependentPostureRunOnAndroid() {
        Pose p=new Pose();DeepseekExpressions e=new DeepseekExpressions();DeepseekPosture posture=new DeepseekPosture();
        e.emotion("playful");e.trigger("爱心眼","右wink",Arrays.asList("脸红","流冷汗"),"装懂小老师");
        posture.request("speech:0",0);float full=0;
        for(int i=0;i<300;i++) {
            p.values.clear();e.apply(1f/60,false,p);e.overlay(p,true);
            p.write("key11",0);e.accessory(p);posture.apply(1f/60,p);
            DeepseekSpeechMouth.apply(.4f,p);
            if(i==30) {
                assertTrue(p.current("key4")>.9f);assertTrue(p.current("key7")>.9f);assertTrue(p.current("key13")>.9f);
                assertTrue(p.current("key11")>.9f);assertTrue(p.current("ParamEyeROpen")<.01f);
                assertTrue(p.current("ParamMouthForm")>.8f);assertEquals(.48f,p.current("ParamMouthOpenY"),.001f);
                assertEquals(0,p.current("MouthX"),0);
            }
            if(p.current("LeanInput")==-30) full+=1f/60;
        }
        assertTrue(full>=2.49f);assertFalse(posture.active());
        e.clearTransient();p.write("key11",0);e.accessory(p);assertEquals(0,p.current("key11"),0);
        DeepseekViewerFocus focus=new DeepseekViewerFocus();
        for(int i=0;i<60;i++) {
            p.write("AngleX",25);p.write("AngleY",-24);focus.apply(.05f,p,true,false);
        }
        assertEquals(-25f/30*.85f,p.current("ParamEyeBallX"),.001f);
        assertEquals(.56f,p.current("ParamEyeBallY"),.001f);assertEquals(25,p.current("AngleX"),0);
    }

}
