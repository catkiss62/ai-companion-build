package com.catkiss.senlive2dcompanion;

import java.util.*;
import org.junit.Test;
import static org.junit.Assert.*;

public class DeepseekGazeTest {
    static float[] identity() {return new float[]{1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1};}
    static final class Pose implements DeepseekParameterPlan.Target {
        final Map<String,Float> values=new HashMap<>();
        public boolean accepts(String id) {return true;}
        public float current(String id) {return values.getOrDefault(id,id.endsWith("Open")?1f:0f);}
        public void write(String id,float value) {values.put(id,value);}
    }
    @Test public void windowAndDirectStageTouchesMeetDespiteAppBarsAndKeyboard() {
        float[] fromWindow=Live2DTouchCoordinates.stage(940,1700,10,200,1000,1600);
        float[] local=Live2DTouchCoordinates.window(930,1500,1000,1600);
        assertArrayEquals(local,fromWindow,0);
        assertArrayEquals(new float[]{1,-1},Live2DTouchCoordinates.stage(1200,1900,10,200,1000,1000),0);
        assertNull(Live2DTouchCoordinates.stage(2,3,0,0,0,10));
        assertNull(Live2DTouchCoordinates.stage(Float.NaN,3,0,0,10,10));
        assertArrayEquals(new float[]{.8f,-.8f},Live2DTouchCoordinates.window(900,1800,1000,2000),.00001f);
    }
    @Test public void sendCornerLooksDownFromRenderedEyesWithOnePixelScale() {
        DeepseekGaze gaze=new DeepseekGaze();
        gaze.capture(identity(),new DeepseekLegPivot.Bounds(-.2f,.2f,.5f,.3f),1000,1800);
        float[] aim=gaze.direction(.8f,-.9f);
        assertEquals(.8f,aim[0],.00001f);assertEquals(-1,aim[1],0);
        assertArrayEquals(new float[]{0,0},gaze.direction(0,.4f),.00001f);
        assertNull(gaze.direction(0,Float.POSITIVE_INFINITY));
    }
    @Test public void finalTransformOwnsNormalSmallCropAndKeyboardEyeOrigin() {
        for(float scale:new float[]{1,.55f}) for(float height:new float[]{1800,950}) {
            DeepseekGaze gaze=new DeepseekGaze();float[] finalMvp=identity();
            finalMvp[0]=scale;finalMvp[5]=scale*1.2f;
            finalMvp[12]=.13f;finalMvp[13]=-.17f;
            DeepseekLegPivot.Bounds whites=new DeepseekLegPivot.Bounds(-.2f,.2f,.5f,.3f);
            gaze.capture(finalMvp,whites,1000,height);
            float eyeY=.4f*scale*1.2f-.17f;
            assertArrayEquals(new float[]{0,0},gaze.direction(.13f,eyeY),.00001f);
            assertArrayEquals(new float[]{.2f,-.2f*height/1000},gaze.direction(.33f,eyeY-.2f),.00001f);
            gaze.capture(identity(),new DeepseekLegPivot.Bounds(),1000,height);
            assertArrayEquals(new float[]{0,0},gaze.direction(.13f,eyeY),.00001f);
            gaze.clear();assertArrayEquals(new float[]{.13f,eyeY},gaze.direction(.13f,eyeY),0);
        }
    }
    @Test public void downGainChangesOnlyEyeDownAndKeepsHeadAndBodyRange() {
        for(float y:new float[]{-1,1}) {
            DeepseekIdleMotion idle=new DeepseekIdleMotion();Pose p=new Pose();
            idle.look(true,1,y);
            for(int i=0;i<12;i++) {idle.update(.05f,p);idle.applyAttention(p,1);}
            assertEquals(y<0?-.9f:.7f,p.current("ParamEyeBallY"),.02f);
            assertEquals(.8f,p.current("ParamEyeBallX"),.02f);
            assertEquals(y*26,p.current("AngleY"),.5f);
            assertEquals(27,p.current("AngleX"),.5f);
            assertEquals(-8,p.current("PositionZ"),.2f);
        }
    }
    @Test public void footProbeSeparatesRotationAndTravelWithoutMutatingAnyMatrix() {
        float[] base=identity(),crop=identity();crop[0]=1.4f;crop[5]=1.4f;crop[13]=.1f;
        float[] root=DeepseekLegPivot.matrix(1000,1800,0,-.3f,1,.1f,8);
        float[] oldBase=base.clone(),oldRoot=root.clone(),oldCrop=crop.clone();
        DeepseekFootProbe probe=new DeepseekFootProbe();
        probe.capture(base,root,crop,new DeepseekLegPivot.Bounds(-.2f,.2f,-.2f,-.5f),0,-.3f,.1f);
        String t=probe.trace();assertTrue(t.contains("visible_leg_bounds_lower"));
        float[] before=pair(t,"legBeforeRoot="),tilt=pair(t,"legAfterTilt="),draw=pair(t,"legDraw=");
        assertArrayEquals(new float[]{0,-.6f},before,.00001f);
        assertEquals(.14f,draw[0]-tilt[0],.00001f);assertEquals(draw[1],tilt[1],0);
        assertTrue(Math.abs(tilt[0]-before[0])>.01f);
        assertArrayEquals(oldBase,base,0);assertArrayEquals(oldRoot,root,0);assertArrayEquals(oldCrop,crop,0);
        probe.capture(base,root,crop,new DeepseekLegPivot.Bounds(),0,0,0);
        assertTrue(probe.trace().contains("lowerLegRef=unavailable"));
    }
    private static float[] pair(String trace,String key) {
        String[] p=trace.substring(trace.indexOf(key)+key.length()).split(" ")[0].split(",");
        return new float[]{Float.parseFloat(p[0]),Float.parseFloat(p[1])};
    }
    @Test public void halfDisgustNeutralDoesNotStealEmotionAndRecoversToNormalForm() {
        Map<String,Float> small=DeepseekExpressions.smallNeutral();
        assertEquals(.775f,small.get("ParamEyeLOpen"),.00001f);
        assertEquals(.4f,small.get("MouthX"),.00001f);
        assertEquals(-.225f,small.get("EyeSmile"),.00001f);
        assertEquals(-1,small.get("ParamMouthForm"),0);
        assertFalse(small.containsKey("key6"));
        DeepseekExpressions e=new DeepseekExpressions();Pose p=new Pose();
        for(int i=0;i<30;i++) e.apply(.1f,true,p);
        assertEquals(.775f,p.current("ParamEyeROpen"),.001f);
        e.emotion("surprised");for(int i=0;i<30;i++) e.apply(.1f,true,p,1);
        assertEquals(1.5f,p.current("ParamEyeROpen"),.001f);
        e.emotion("normal");for(int i=0;i<30;i++) e.apply(.1f,true,p,0);
        assertEquals(.775f,p.current("ParamEyeROpen"),.001f);
        for(int i=0;i<30;i++) e.apply(.1f,false,p);
        assertEquals(1,p.current("ParamEyeROpen"),.001f);
        assertEquals(0,p.current("EyeSmile"),.001f);
    }
}
