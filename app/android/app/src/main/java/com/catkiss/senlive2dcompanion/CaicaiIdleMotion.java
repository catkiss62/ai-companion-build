package com.catkiss.senlive2dcompanion;

/** Local performance, expressed in the owner's calibrated maid parameter space.
 * No network work here. Continuous asymmetric movement plus bounded emphasis phrases. */
final class CaicaiIdleMotion {
    private float clock, attention, targetX, targetY, x, y;
    private float gain=1f, speed=1f;
    void tune(float gain,float speed) { this.gain=gain; this.speed=speed; }
    void clearAttention() { attention=0; x=0; y=0; }
    void look(boolean active, float nx, float ny) {
        if (active) { targetX = Math.max(-1, Math.min(1, nx));
            targetY = Math.max(-1, Math.min(1, ny)); attention = 1.8f; }
    }
    private static float wave(float t, float seed) {
        return .5f*(float)Math.sin(.7f*t+seed) + .3f*(float)Math.sin(1.9f*t+2.7f*seed)
            + .2f*(float)Math.sin(3.7f*t+5.1f*seed);
    }
    void update(float dt, CaicaiParameterPlan.Target out) {
        if (dt <= 0) return;
        clock += dt*speed;
        attention = Math.max(0, attention-dt);
        float follow = Math.min(1, attention/.55f);
        float ease = 1-(float)Math.exp(-dt/ .12f);
        x += (targetX*follow-x)*ease; y += (targetY*follow-y)*ease;
        // Each phrase has a complete entry/exit. Alternate direction and shape,
        // without a repeating pendulum or a discontinuous pulse reset.
        int phrase = (int)(clock/3.2f);
        float phase = clock%3.2f;
        float pulse = phase < 1.35f ? (float)Math.pow(Math.sin(Math.PI*phase/1.35f),2) : 0;
        float side = phrase%2 == 0 ? 1 : -1;
        float head = wave(clock*1.35f,.4f)*24 + side*pulse*13;
        float pitch = wave(clock*1.25f,1.9f)*21 + pulse*(phrase%3 == 0 ? 13 : -10);
        float tilt = wave(clock*1.20f,3.2f)*19 + side*pulse*10;
        put(out,"ParamAngleX3", gain*(head*(1-.55f*follow)+x*29));
        put(out,"ParamAngleY2", gain*(pitch*(1-.55f*follow)+y*27));
        put(out,"ParamAngleZ",gain*tilt); put(out,"ParamAngleZ2",gain*tilt);
        put(out,"ParamBodyAngleX",gain*(wave(clock*.95f,.7f)*12+side*pulse*4));
        put(out,"ParamBodyAngleY",gain*(wave(clock*1.05f,2.2f)*10+pulse*(phrase%3 == 1 ? 5 : -4)));
        put(out,"ParamBodyAngleZ",gain*(wave(clock*.98f,4.2f)*13-side*pulse*5));
        put(out,"@rootX",gain*side*pulse*.065f);
        put(out,"@rootTilt",gain*side*pulse*4.5f);
        // Eye motion remains separate from head lean; touch has immediate priority.
        put(out,"ParamEyeBallX",x*.85f+wave(clock*.6f,1)*.20f*(1-follow));
        put(out,"ParamEyeBallY",y*.8f+wave(clock*.5f,2)*.15f*(1-follow));
    }
    void applyAttention(CaicaiParameterPlan.Target out) {
        float weight=Math.min(1,attention/.55f);
        if(weight <= 0) return;
        for(String id : new String[]{"ParamAngleX3","ParamAngleY2","ParamEyeBallX","ParamEyeBallY","ParamBodyAngleZ","ParamBodyAngleY"}) {
            float value=id.equals("ParamAngleX3") ? x*29*gain : id.equals("ParamAngleY2") ? y*27*gain
                : id.equals("ParamEyeBallX") ? x*.85f : id.equals("ParamEyeBallY") ? y*.8f
                : id.equals("ParamBodyAngleZ") ? -x*8*gain : y*6*gain;
            if(out.accepts(id)) out.write(id,out.current(id)*(1-weight)+value*weight);
        }
    }
    private static void put(CaicaiParameterPlan.Target out,String id,float value) {
        if(out.accepts(id)) out.write(id,value);
    }
}
