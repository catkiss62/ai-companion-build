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
        // AngleX has a much larger visual range than Caicai's control rig.
        put(target,"AngleX",clamp(gain*(wave(clock*1.05f,.4f)*2.6f+side*pulse*(family==0?2.5f:1.4f)),6));
        put(target,"AngleY",clamp(gain*(wave(clock*.93f,1.8f)*2.4f+pulse*(family==2?2:family==3?-2:0)),6));
        put(target,"AngleZ",clamp(gain*(wave(clock*.87f,3.2f)*2+side*pulse*(family==4?2:1)),5));
        put(target,"PositionX",clamp(gain*(wave(clock*.65f,.7f)*1.05f+side*pulse*.45f),2.2f));
        put(target,"PositionY",clamp(gain*(wave(clock*.72f,2.2f)*.8f+pulse*(family==5?.7f:-.2f)),2));
        put(target,"PositionZ",clamp(gain*(wave(clock*.62f,4.2f)*1.1f-side*pulse*.4f),2.2f));
        put(target,"LeanInput",0);
        put(target,"@rootX",clamp(gain*side*pulse*(family==6?.014f:.009f),.02f));
        put(target,"@rootTilt",clamp(gain*side*pulse*(family==7?1.1f:.7f),1.6f));
        put(target,"ParamEyeBallX",wave(clock*.48f,1)*.17f);
        put(target,"ParamEyeBallY",wave(clock*.43f,2)*.12f);
    }
    void applyAttention(DeepseekParameterPlan.Target target,float headWeight) {
        float follow=Math.min(1,attention/.55f);
        if(follow<=0) return;
        mix(target,"ParamEyeBallX",x*.8f,follow);
        mix(target,"ParamEyeBallY",y*.7f,follow);
        mix(target,"AngleX",clamp(x*5.5f*gain,8),follow*headWeight);
        mix(target,"AngleY",clamp(y*4.5f*gain,7),follow*headWeight);
    }
    private static void mix(DeepseekParameterPlan.Target t,String id,float value,float weight) {
        if(t.accepts(id)) t.write(id,t.current(id)+(value-t.current(id))*weight);
    }
    private static float clamp(float value,float limit) {return Math.max(-limit,Math.min(limit,value));}
    private static void put(DeepseekParameterPlan.Target t,String id,float value) {if(t.accepts(id)) t.write(id,value);}
}
