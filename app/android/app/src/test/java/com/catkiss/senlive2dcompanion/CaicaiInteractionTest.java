package com.catkiss.senlive2dcompanion;

import org.junit.Test;
import java.util.*;
import static org.junit.Assert.*;

public class CaicaiInteractionTest {
    private static class Pose implements CaicaiParameterPlan.Target {
        final Map<String,Float> v=new HashMap<>();
        public boolean accepts(String id) { return CaicaiParameterPlan.supports(id); }
        public float current(String id) { return v.getOrDefault(id,0f); }
        public void write(String id,float value) { v.put(id,value); }
    }
    @Test public void finalHeadIntentSurvivesPhysicsForEveryOwner() throws Exception {
        for(String owner:new String[]{"idle","gaze","jev"}) {
            Pose pose=new Pose(); CaicaiHeadPose head=new CaicaiHeadPose(); head.begin();
            if(owner.equals("jev")) {
                CaicaiParameterPlan plan=new CaicaiParameterPlan();
                plan.start("[{\"time\":0,\"duration\":0.1,\"parameters\":{\"ParamAngleX3\":27,\"ParamAngleY2\":-24}}]");
                plan.apply(.1f,pose);
            } else {
                CaicaiIdleMotion idle=new CaicaiIdleMotion(new Random(71));
                if(owner.equals("gaze")) idle.look(true,1,-1);
                for(int i=0;i<10;i++) idle.update(1f/60,pose);
                if(owner.equals("gaze")) idle.applyAttention(pose);
            }
            for(String id:new String[]{"ParamAngleX3","ParamAngleY2"}) head.record(id,pose.current(id));
            float x=pose.current("ParamAngleX3"),y=pose.current("ParamAngleY2");
            pose.write("ParamAngleX3",.1f); pose.write("ParamAngleY2",.2f);
            pose.write("ParamMouthOpenY",.8f); head.finish(pose);
            assertEquals(owner,x,pose.current("ParamAngleX3"),.001f);
            assertEquals(owner,y,pose.current("ParamAngleY2"),.001f);
            assertEquals(.8f,pose.current("ParamMouthOpenY"),.001f);
        }
    }
    @Test public void keyboardCropsWithoutChangingPixelSizeOrTopPosition() {
        CaicaiSceneCamera camera=new CaicaiSceneCamera(); camera.setScene(400,760);
        for(float height:new float[]{760,700,520,440,520,760}) {
            float[] m=camera.crop(1200,height*3);
            for(float y:new float[]{1,.6f,0,-1}) {
                float pixel=(1-(m[5]*y+m[13]))*(height*3)/2;
                assertEquals((1-y)*760*3/2,pixel,.001f);
            }
        }
        camera.setScene(800,360);
        assertEquals(1080,camera.height(2400,500),.001f);
    }
    @Test public void emotionEndsAtFourAndHalfSecondsAndNeverRearmsFromRevision() {
        CaicaiEmotionLease lease=new CaicaiEmotionLease(); long start=10_000_000_000L;
        lease.present("reply-1","sad",start);
        lease.present("reply-1","happy",start+3_000_000_000L);
        assertEquals("happy",lease.emotion());
        assertEquals(1,lease.weight(start+4_000_000_000L),.0001f);
        assertEquals(.5f,lease.weight(start+4_310_000_000L),.0001f);
        assertEquals(0,lease.weight(start+4_500_000_000L),.0001f);
        lease.present("reply-1","happy",start+8_000_000_000L);
        assertEquals(0,lease.weight(start+8_000_000_000L),.0001f);
        lease.present("reply-2","sad",start+9_000_000_000L);
        lease.present("reply-1","happy",start+9_100_000_000L);
        assertEquals("sad",lease.emotion());
    }
    @Test public void patBlendsCurrentFaceHoldsAndReleasesWhileGazeSurvives() {
        Pose p=new Pose(); p.write("ParamEyeLOpen",.4f); p.write("ParamEyeROpen",.6f);
        CaicaiHeadPat pat=new CaicaiHeadPat(); pat.start(true,false,p);
        p.write("ParamEyeLOpen",1); pat.apply(.001f,p);
        assertEquals(.4f,p.current("ParamEyeLOpen"),.001f);
        for(int i=0;i<600;i++) {
            p.write("ParamEyeLOpen",1); p.write("ParamEyeBallX",.75f);
            pat.apply(1f/60,p);
        }
        assertTrue(pat.active()); assertEquals("held",pat.state());
        assertEquals(.15f,p.current("ParamEyeLOpen"),.001f);
        assertEquals(.75f,p.current("ParamEyeBallX"),.001f);
        assertTrue(pat.followWeight()>0);
        pat.release(); for(int i=0;i<40;i++) { p.write("ParamEyeLOpen",1); pat.apply(1f/60,p); }
        assertFalse(pat.active()); assertEquals(1,p.current("ParamEyeLOpen"),.001f);
    }
    @Test public void rarePatCompletesEvenWhenFingerRemainsDown() {
        Pose p=new Pose(); CaicaiHeadPat pat=new CaicaiHeadPat(); pat.start(true,true,p);
        for(int i=0;i<120;i++) pat.apply(1f/60,p);
        assertTrue(pat.active());
        assertFalse(pat.start(true,false,p));
        for(int i=0;i<46;i++) pat.apply(1f/60,p);
        assertTrue(pat.active());
        for(int i=0;i<3;i++) pat.apply(1f/60,p);
        assertFalse(pat.active());
    }
    @Test public void idleVariantsAvoidTheLastThreeFamilies() {
        CaicaiIdleMotion idle=new CaicaiIdleMotion(new Random(71)); Pose p=new Pose();
        ArrayDeque<String> recent=new ArrayDeque<>(); String last=""; int changes=0;
        for(int i=0;i<12000;i++) {
            idle.update(1f/60,p); String name=idle.phraseName();
            if(name.equals(last)) continue;
            String family=name.split(":")[0]; assertFalse(recent.contains(family));
            recent.addLast(family); if(recent.size()>3) recent.removeFirst();
            last=name; changes++;
        }
        assertTrue(changes>35);
    }
    @Test public void diagnosticRingIsBoundedAndCountsModelFramesSeparately() throws Exception {
        CaicaiFrameDiagnostics d=new CaicaiFrameDiagnostics();
        long now=1_000_000_000L;
        for(int i=0;i<240;i++) { now+=1_010_000_000L; d.frame(now,i<5,()->"no-private-data"); }
        org.json.JSONObject json=new org.json.JSONObject(d.export());
        assertEquals(180,json.getJSONArray("samples").length());
        assertFalse(json.getBoolean("visibilityProof"));
    }
}
