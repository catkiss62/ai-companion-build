package com.catkiss.senlive2dcompanion;

import java.util.ArrayDeque;
import java.util.Random;

/** Local lower layer for this rig. No face, mouth, outfit, physics-output or network ownership. */
final class DeepseekIdleMotion {
    private final Random random;
    private final ArrayDeque<Integer> recent=new ArrayDeque<>();
    private float clock,age,duration,accent,side,variation,gain=1,speed=1;
    private float attention,targetX,targetY,x,y,quiet,grassWait;
    private int family;
    DeepseekIdleMotion() {this(new Random());}
    DeepseekIdleMotion(Random random) {this.random=random;nextPhrase();resetGrass();}
    void tune(float gain,float speed) {
        this.gain=Math.max(.5f,Math.min(1.5f,gain));
        this.speed=Math.max(.65f,Math.min(1.6f,speed));
    }
    private void nextPhrase() {
        do {family=random.nextInt(8);} while(recent.contains(family));
        recent.addLast(family);if(recent.size()>3) recent.removeFirst();
        duration=2.8f+random.nextFloat()*2.2f;accent=1.4f+random.nextFloat()*.7f;
        side=random.nextBoolean()?1:-1;variation=.8f+random.nextFloat()*.4f;
    }
    void look(boolean active,float nx,float ny) {
        if(!active) {attention=Math.min(attention,.55f);return;}
        if(!Float.isFinite(nx) || !Float.isFinite(ny)) return;
        targetX=clamp(nx,1);targetY=clamp(ny,1);attention=1.8f;
    }
    void clearAttention() {attention=targetX=targetY=x=y=0;quiet=0;}
    void resetGrass() {quiet=0;grassWait=35+random.nextFloat()*45;}
    boolean grassDue(float dt,boolean blocked) {
        if(blocked || attention>0) {quiet=0;return false;}
        quiet+=Math.max(0,dt);grassWait-=Math.max(0,dt);
        if(quiet<2 || grassWait>0) return false;
        resetGrass();return true;
    }
    boolean attentive() {return attention>0;}
    String trace() {return family+":"+side+":"+variation+" follow="+attention;}
    int family() {return family;}
    float breath() {return .5f+.12f*(float)Math.sin(clock*1.3f);}
    private static float wave(float t,float phase) {
        return .6f*(float)Math.sin(t*.7f+phase)+.27f*(float)Math.sin(t*1.7f+phase*2.3f)
            +.13f*(float)Math.sin(t*2.9f+phase*4.1f);
    }
    void update(float dt,DeepseekParameterPlan.Target target) {
        dt=Math.max(0,Math.min(.1f,dt));clock+=dt*speed;age+=dt*speed;
        attention=Math.max(0,attention-dt);
        float follow=Math.min(1,attention/.55f),ease=1-(float)Math.exp(-dt/.14f);
        x+=(targetX*follow-x)*ease;y+=(targetY*follow-y)*ease;
        if(age>=duration) {age-=duration;nextPhrase();}
        float pulse=age<accent?variation*(float)Math.pow(Math.sin(Math.PI*age/accent),2):0;
        // Most of idle faces the viewer. A few short accents glance away and return;
        // roll/body energy stays intact. Explicit attention and JEV still own their full range.
        float glance=family==0 || family==2 || family==3?Math.min(1,pulse):0;
        float focus=.25f+.75f*glance;
        float headX=clamp(gain*(wave(clock*1.05f,.4f)*22*focus+side*pulse*(family==0?14:2)),30);
        float headY=clamp(gain*(wave(clock*.93f,1.8f)*21*focus+pulse*(family==2?17:family==3?-16:0)),30);
        put(target,"AngleX",headX);
        put(target,"AngleY",headY);
        put(target,"AngleZ",clamp(gain*(wave(clock*.87f,3.2f)*19+side*pulse*(family==4?15:9)),30));
        put(target,"PositionX",clamp(gain*(wave(clock*.95f,.7f)*24+side*pulse*8),30));
        put(target,"PositionY",clamp(gain*(wave(clock*1.05f,2.2f)*24+pulse*(family%3==1?12:-8)),30));
        put(target,"PositionZ",clamp(gain*(wave(clock*.98f,4.2f)*26-side*pulse*10),30));
        put(target,"LeanInput",0);
        put(target,"@rootX",clamp(gain*side*pulse*(family==6?.075f:.055f),.15f));
        put(target,"@rootTilt",clamp(gain*side*pulse*(family==7?6:4.5f),10));
        // Gently counter the resting head turn instead of independently scanning the room.
        put(target,"ParamEyeBallX",clamp(-headX/30*.35f+wave(clock*.48f,1)*.06f,.5f));
        put(target,"ParamEyeBallY",clamp(-headY/30*.3f+wave(clock*.43f,2)*.05f,.5f));
    }
    void applyAttention(DeepseekParameterPlan.Target target,float headWeight) {
        float follow=Math.min(1,attention/.55f);
        if(follow<=0) return;
        mix(target,"ParamEyeBallX",x*.8f,follow);
        mix(target,"ParamEyeBallY",y*(y<0?.9f:.7f),follow);
        mix(target,"AngleX",clamp(x*27*gain,30),follow*headWeight);
        mix(target,"AngleY",clamp(y*26*gain,30),follow*headWeight);
        mix(target,"PositionZ",clamp(-x*8*gain,30),follow*headWeight);
        mix(target,"PositionY",clamp(y*6*gain,30),follow*headWeight);
    }
    private static void mix(DeepseekParameterPlan.Target t,String id,float value,float weight) {
        // Reapply the authored bound after lerp: float cancellation at full weight
        // can produce -30.000002 even when both endpoints are within -30..30.
        if(t.accepts(id)) t.write(id,DeepseekParameterPlan.spatialValue(id,
            t.current(id)+(value-t.current(id))*weight));
    }
    private static float clamp(float value,float limit) {return Math.max(-limit,Math.min(limit,value));}
    private static void put(DeepseekParameterPlan.Target t,String id,float value) {if(t.accepts(id)) t.write(id,value);}
}
