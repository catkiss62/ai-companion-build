package com.catkiss.senlive2dcompanion;

/** One independent approach/hold/return. A speech beat cannot replace this owner. */
final class DeepseekPosture {
    static final float APPROACH=1.05f,HOLD=2.5f,RETURN=1.05f;
    private int phase;
    private float age,delay,value,from;
    private String lastToken="";
    boolean active() {return phase!=0;}
    void clear() {phase=0;age=delay=value=from=0;lastToken="";}
    void request(String token,float delay) {
        if(token==null || token.isEmpty() || token.equals(lastToken) || active()) return;
        lastToken=token;this.delay=Float.isFinite(delay)?Math.max(0,Math.min(2.5f,delay)):0;
        phase=this.delay>0?1:2;age=0;from=value;
    }
    void release() {
        if(phase==0 || phase==4) return;
        if(phase==1) {phase=0;return;}
        phase=4;age=0;from=value;
    }
    void apply(float dt,DeepseekParameterPlan.Target pose) {
        if(!active()) return;
        float left=Float.isFinite(dt)?Math.max(0,Math.min(.1f,dt)):0;
        while(left>0 && active()) {
            float duration=phase==1?delay:phase==2?APPROACH:phase==3?HOLD:RETURN;
            float step=Math.min(left,Math.max(0,duration-age));age+=step;left-=step;
            float t=Math.min(1,age/Math.max(.001f,duration));float smooth=t*t*(3-2*t);
            if(phase==2) value=from+(-30-from)*smooth;
            else if(phase==3) value=-30;
            else if(phase==4) value=from*(1-smooth);
            if(age>=duration-.00001f) {
                if(phase==4) {phase=0;value=0;}
                else {phase++;if(phase==3) value=-30;}
                age=0;from=value;
            }
        }
        if(pose.accepts("LeanInput")) pose.write("LeanInput",value);
    }
    String trace() {return "phase="+phase+" value="+value+" age="+age;}
}
