package com.catkiss.senlive2dcompanion;

import androidx.test.ext.junit.runners.AndroidJUnit4;
import java.util.*;
import org.junit.Test;
import org.junit.runner.RunWith;
import static org.junit.Assert.*;

/** Actual production interaction state on Android; no private model is bundled. */
@RunWith(AndroidJUnit4.class)
public class DeepseekStage3SmokeTest {
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

}
