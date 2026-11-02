package com.catkiss.senlive2dcompanion;

import java.util.*;
import org.junit.Test;
import static org.junit.Assert.*;

public class DeepseekInteractionTest {
    static final class Pose implements DeepseekParameterPlan.Target {
        final Map<String,Float> values=new HashMap<>();
        public boolean accepts(String id) {return true;}
        public float current(String id) {return values.getOrDefault(id,id.endsWith("Open")?1f:0f);}
        public void write(String id,float value) {values.put(id,value);}
        void lower() {values.clear();values.put("ParamEyeLOpen",.8f);values.put("ParamEyeROpen",.8f);}
    }
    @Test public void localIdleIsBoundedSmoothAndNeverOwnsMouthOutfitsOrArms() {
        DeepseekIdleMotion idle=new DeepseekIdleMotion(new Random(17));idle.tune(1.5f,1.6f);Pose pose=new Pose();
        float previous=0;int last=idle.family();ArrayDeque<Integer> recent=new ArrayDeque<>();recent.add(last);
        Set<Integer> seen=new HashSet<>();seen.add(last);
        for(int i=0;i<18000;i++) {
            pose.values.clear();idle.update(1f/60,pose);
            for(Map.Entry<String,Float> value:pose.values.entrySet()) {
                String id=value.getKey();assertTrue(Float.isFinite(value.getValue()));
                assertFalse(DeepseekExpressions.MOUTH.contains(id));assertFalse(id.startsWith("Clothes"));
                assertFalse(DeepseekGestures.CHANNELS.contains(id));assertFalse(id.startsWith("key"));
                float limit=id.equals("@rootX")?.15f:id.equals("@rootTilt")?10:id.startsWith("Angle")?30:id.startsWith("Position")?30:1;
                assertTrue(id,Math.abs(value.getValue())<=limit+.0001f);
            }
            if(i>0) assertTrue(Math.abs(pose.current("AngleX")-previous)<3.5f);previous=pose.current("AngleX");
            assertTrue(idle.breath()>=.37999f && idle.breath()<=.62001f);
            if(idle.family()!=last) {
                assertFalse(recent.contains(idle.family()));recent.addLast(idle.family());
                if(recent.size()>3) recent.removeFirst();last=idle.family();seen.add(last);
            }
        }
        assertEquals(8,seen.size());
    }
    @Test public void attentionUsesScreenDirectionsAndReturnsWithoutHoldingAnOldTarget() {
        DeepseekIdleMotion idle=new DeepseekIdleMotion(new Random(5));Pose pose=new Pose();
        idle.look(true,-1,1);
        for(int i=0;i<40;i++) {pose.lower();idle.update(1f/60,pose);idle.applyAttention(pose,1);}
        assertTrue(pose.current("ParamEyeBallX")<-.7f);assertTrue(pose.current("AngleX")<-25);
        assertTrue(pose.current("ParamEyeBallY")>.6f);assertTrue(pose.current("AngleY")>24);
        assertTrue(pose.current("PositionZ")>7);assertTrue(pose.current("PositionY")>5);
        idle.look(false,0,0);
        for(int i=0;i<100;i++) {pose.lower();idle.update(1f/60,pose);idle.applyAttention(pose,1);}
        assertFalse(idle.attentive());float restingEye=pose.current("ParamEyeBallX");idle.applyAttention(pose,1);
        assertEquals(restingEye,pose.current("ParamEyeBallX"),0);
        idle.look(true,Float.NaN,1);assertFalse(idle.attentive());
    }
    @Test public void grassIsOccasionalAndNeverRequestedDuringHigherPriorityWorkOrTouch() {
        DeepseekIdleMotion idle=new DeepseekIdleMotion(new Random(2));Pose pose=new Pose();int requested=0;
        for(int i=0;i<18000;i++) {idle.update(1f/60,pose);if(idle.grassDue(1f/60,false)) requested++;}
        assertTrue(requested>=3 && requested<=8);
        for(int i=0;i<18000;i++) assertFalse(idle.grassDue(1f/60,true));
        idle.look(true,1,0);assertFalse(idle.grassDue(500,false));
        idle.clearAttention();idle.resetGrass();assertFalse(idle.grassDue(1,false));
    }
    @Test public void naturalBlinkPreservesEmotionalOpeningAndDefersToExplicitEyes() {
        DeepseekBlink blink=new DeepseekBlink(new Random(3));Pose pose=new Pose();boolean closed=false;
        for(int i=0;i<900;i++) {
            pose.lower();blink.update(1f/60,false,pose);
            closed|=pose.current("ParamEyeLOpen")<.05f;
            assertTrue(pose.current("ParamEyeLOpen")<=.8f);assertEquals(pose.current("ParamEyeLOpen"),pose.current("ParamEyeROpen"),0);
            assertFalse(pose.values.containsKey("ParamMouthForm"));
        }
        assertTrue(closed);
        for(int i=0;i<900;i++) {pose.lower();blink.update(1f/60,true,pose);assertEquals(.8f,pose.current("ParamEyeLOpen"),0);}
    }
    @Test public void heldComfortFadesToTheLiveFaceAndRareReactionCannotBeInterruptedByAnotherPat() {
        DeepseekHeadPat pat=new DeepseekHeadPat();Pose pose=new Pose();
        assertTrue(pat.start(true,false,pose));
        for(int i=0;i<600;i++) {pose.lower();pat.apply(1f/60,false,pose);}
        assertEquals("held",pat.state());assertEquals(.12f,pose.current("ParamEyeLOpen"),.001f);
        assertTrue(pose.current("ParamMouthForm")>.6f);assertFalse(pat.start(true,false,pose));
        pat.release();for(int i=0;i<40;i++) {pose.lower();pat.apply(1f/60,false,pose);}
        assertFalse(pat.active());assertEquals(.8f,pose.current("ParamEyeLOpen"),.001f);
        assertTrue(pat.start(true,true,pose));
        for(int i=0;i<166;i++) {
            pose.lower();pat.apply(1f/60,false,pose);pat.release();
            assertFalse(pat.start(false,false,pose));assertFalse(pat.start(true,true,pose));
        }
        for(int i=0;i<5;i++) {pose.lower();pat.apply(1f/60,false,pose);}
        assertFalse(pat.active());assertTrue(pat.start(false,false,pose));
    }
    @Test public void smallFormPatKeepsTsundereMouthAndClearsConflictingSpecialEyes() {
        DeepseekHeadPat pat=new DeepseekHeadPat();Pose pose=new Pose();pose.write("key4",1);
        pat.start(true,false,pose);
        for(int i=0;i<40;i++) {pose.lower();pat.apply(1f/60,true,pose);}
        assertTrue(pose.current("ParamMouthForm")<-.6f);assertEquals(0,pose.current("key4"),0);
        assertFalse(pose.values.containsKey("ParamMouthOpenY"));
        pat.cancel();assertFalse(pat.active());assertEquals("idle",pat.state());
    }
    @Test public void patEntersFromTheRenderedHeadInsteadOfSnappingAConversationToIdle() {
        DeepseekHeadPat pat=new DeepseekHeadPat();Pose pose=new Pose();
        pose.write("AngleX",28);pose.write("LeanInput",-30);pose.write("@rootTilt",8);pose.write("PositionX",20);
        pat.start(true,false,pose);pose.lower();pat.apply(1f/60,false,pose);
        assertTrue(pose.current("AngleX")>27);assertTrue(pose.current("LeanInput")<-28);
        assertTrue(pose.current("@rootTilt")>7.8f);assertTrue(pose.current("PositionX")>19);
        for(int i=0;i<30;i++) {pose.lower();pat.apply(1f/60,false,pose);}
        assertEquals(0,pose.current("AngleX"),.001f);assertEquals(0,pose.current("LeanInput"),.001f);
    }
    private static DeepseekMotionClip clip(String curves,float duration,Set<String> allowed) throws Exception {
        return new DeepseekMotionClip("{\"Meta\":{\"Duration\":"+duration+",\"Loop\":true},\"Curves\":["+curves+"]}",allowed);
    }
    private static String curve(String id,String segments) {
        return "{\"Target\":\"Parameter\",\"Id\":\""+id+"\",\"Segments\":"+segments+"}";
    }
    @Test public void authoredIdleFiltersEyesMouthClothesTailLightsAndHandsRemainOneOwner() throws Exception {
        String curves=curve("Movement1","[0,0,0,1,1]");
        for(String id:Arrays.asList("key3","key8","ParamEyeLOpen","ParamMouthForm","JawOpen","Clothes2","Param55","AngleY","Movement2"))
            curves+=","+curve(id,"[0,0,0,1,1]");
        DeepseekMotionClip idle=clip(curves,1,DeepseekGestures.IDLE_CHANNELS);
        assertEquals(Collections.singleton("Movement1"),idle.sample(.5f).keySet());
        DeepseekGestures g=new DeepseekGestures();
        DeepseekMotionClip exit=clip(curve("Movement1","[0,1,0,1,0]"),1,DeepseekGestures.IDLE_CHANNELS);
        g.registerAmbient(idle,exit);g.register("竖食指",idle,exit);
        assertTrue(g.requestAmbient());float previous=g.update(.4f).get("Movement1");
        assertTrue(g.ambientActive());assertFalse(g.requestAmbient());
        assertTrue(g.request("竖食指",.5f));assertEquals(previous,g.update(.001f).get("Movement1"),.001f);
        for(int i=0;i<15;i++) g.update(.1f);
        assertFalse(g.ambientActive());assertTrue(g.busy());assertTrue(g.trace().startsWith("竖食指:"));
        g.stop();for(int i=0;i<20;i++) g.update(.1f);
        assertFalse(g.busy());g.clear();assertTrue(g.update(.1f).isEmpty());
    }
    @Test public void hitTestingUsesActualAffineDrawIncludingCropRotationScaleAndMorphedBounds() {
        float[] m={1.3f,.08f,0,0,-.14f,2.7f,0,0,0,0,1,0,.11f,-.9f,0,1};
        float left=-.6f,right=.9f,top=1.5f,bottom=-.8f;
        DeepseekHitTransform hit=new DeepseekHitTransform(m,left,right,top,bottom);
        for(float u:new float[]{.1f,.45f,.8f}) for(float v:new float[]{.05f,.2f,.7f}) {
            float x=left+(right-left)*u,y=top-(top-bottom)*v;
            float sx=(m[0]*x+m[4]*y+m[12]+1)/2,sy=(1-m[1]*x-m[5]*y-m[13])/2;
            float[] out=new float[2];assertTrue(hit.inverse(sx,sy,out));
            assertEquals(u,out[0],.0001f);assertEquals(v,out[1],.0001f);
        }
        m[0]=0;assertTrue(hit.inverse(.5f,.5f,new float[2])); // Snapshot never shares a mutable GL array.
        assertFalse(DeepseekHitTransform.INVALID.inverse(.5f,.5f,new float[2]));
        assertFalse(hit.inverse(Float.NaN,.5f,new float[2]));assertFalse(hit.inverse(.5f,.5f,null));
    }

    @Test public void defaultIdleActuallyUsesHeadBodyAndRootInsteadOfOnlyPassingUpperBounds() {
        DeepseekIdleMotion idle=new DeepseekIdleMotion(new Random(17));Pose pose=new Pose();
        Map<String,Float> peaks=new HashMap<>();
        for(int i=0;i<18000;i++) {
            pose.values.clear();idle.update(1f/60,pose);
            for(Map.Entry<String,Float> e:pose.values.entrySet())
                peaks.put(e.getKey(),Math.max(peaks.getOrDefault(e.getKey(),0f),Math.abs(e.getValue())));
        }
        for(String id:Arrays.asList("AngleX","AngleY","AngleZ")) assertTrue(id+peaks,peaks.get(id)>18);
        for(String id:Arrays.asList("PositionX","PositionY","PositionZ")) assertTrue(id+peaks,peaks.get(id)>8);
        assertTrue(peaks.toString(),peaks.get("@rootX")>.05f);assertTrue(peaks.toString(),peaks.get("@rootTilt")>4);
    }
    @Test public void puzzledEggHasDistinctVisibleEyesBrowsAndBodyThroughoutItsHold() {
        DeepseekHeadPat pat=new DeepseekHeadPat();Pose pose=new Pose();pat.start(false,true,pose);
        for(int i=0;i<120;i++) {pose.lower();pat.apply(1f/60,false,pose);}
        assertEquals("easter_egg",pat.state());
        assertEquals(.7f,pose.current("ParamEyeLOpen"),.001f);
        assertEquals(1.35f,pose.current("ParamEyeROpen"),.001f);
        assertTrue(pose.current("ParamBrowRY")-pose.current("ParamBrowLY")>1.4f);
        assertTrue(pose.current("MouthX")>.7f);assertEquals(-12,pose.current("AngleZ"),.01f);
        assertEquals(-10,pose.current("AngleY"),.01f);assertEquals(-4,pose.current("PositionY"),.01f);
        pat.release();assertFalse(pat.start(true,false,pose));
    }

    @Test public void idleUsuallyFacesViewerButStillHasBriefGlancesAndLivelyRollAndBody() {
        DeepseekIdleMotion idle=new DeepseekIdleMotion(new Random(17));Pose p=new Pose();
        int centered=0,glances=0;float rollPeak=0,bodyPeak=0;
        for(int i=0;i<18000;i++) {
            p.values.clear();idle.update(1f/60,p);
            float hx=p.current("AngleX"),hy=p.current("AngleY");
            if(Math.abs(hx)<=9 && Math.abs(hy)<=9) centered++;
            if(Math.abs(hx)>18 || Math.abs(hy)>18) glances++;
            rollPeak=Math.max(rollPeak,Math.abs(p.current("AngleZ")));
            bodyPeak=Math.max(bodyPeak,Math.abs(p.current("PositionZ")));
            // Unprompted eyes counter the head instead of reinforcing room-scanning.
            assertTrue(Math.abs(p.current("ParamEyeBallX")+hx/30*.35f)<=.06001f);
            assertTrue(Math.abs(p.current("ParamEyeBallY")+hy/30*.3f)<=.05001f);
        }
        assertTrue("centered="+centered,centered>18000*.8f);
        assertTrue("glances="+glances,glances>50 && glances<18000*.15f);
        assertTrue(rollPeak>18);assertTrue(bodyPeak>12);
    }
    @Test public void smallFormScreenGuardContainsFinalTransformedCornersWithoutChangingNormalStage() {
        float[] base={.55f,.12f,0,0,-.16f,1.7f,0,0,0,0,1,0,0,-.8f,0,1};
        for(float travel:new float[]{-2,-1.2f,-.5f,0,.5f,1.2f,2}) {
            float[] m=base.clone();m[12]=travel;float[] before=m.clone();
            assertEquals(0,DeepseekHitTransform.smallFormShift(m,-.4f,.4f,.5f,-.5f,0),0);
            float shift=DeepseekHitTransform.smallFormShift(m,-.4f,.4f,.5f,-.5f,1);
            assertArrayEquals(before,m,0); // No persistent stage / input matrix mutation.
            m[12]+=shift;
            for(float x:new float[]{-.4f,.4f}) for(float y:new float[]{-.5f,.5f}) {
                float sx=m[0]*x+m[4]*y+m[12];assertTrue(sx>=-.94001f && sx<=.94001f);
            }
            float[] point=new float[2];DeepseekHitTransform hit=new DeepseekHitTransform(m,-.4f,.4f,.5f,-.5f);
            assertTrue(hit.inverse((m[12]+1)/2,(1-m[13])/2,point));
            assertEquals(.5f,point[0],.0001f);assertEquals(.5f,point[1],.0001f);
            assertEquals(shift*.5f,DeepseekHitTransform.smallFormShift(before,-.4f,.4f,.5f,-.5f,.5f),.0001f);
        }
        assertEquals(0,DeepseekHitTransform.smallFormShift(base,-4,4,1,-1,1),0); // Intentional oversized zoom.
        assertEquals(0,DeepseekHitTransform.smallFormShift(null,-1,1,1,-1,1),0);
        base[0]=Float.NaN;assertEquals(0,DeepseekHitTransform.smallFormShift(base,-1,1,1,-1,1),0);
    }
    @Test public void smallFormTravelSoftensContinuouslyAtTheEdgeAndLeavesCentralMovementUntouched() {
        float[] m={1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1};
        assertEquals(0,DeepseekHitTransform.smallFormShift(m,-.2f,.2f,.3f,-.3f,1),0);
        float last=-1;
        for(int i=0;i<=2000;i++) {
            m[12]=i*.001f;float adjusted=m[12]+DeepseekHitTransform.smallFormShift(m,-.2f,.2f,.3f,-.3f,1);
            assertTrue(adjusted>=last-.000001f);
            if(i>0) assertTrue(adjusted-last<=.00101f);
            last=adjusted;
        }
        assertTrue(last<=.740001f);
    }
}
