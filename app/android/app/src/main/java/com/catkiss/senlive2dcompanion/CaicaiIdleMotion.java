package com.catkiss.senlive2dcompanion;

/** Local performance, expressed in the owner's calibrated maid parameter space.
 * No network work here. Continuous asymmetric movement plus bounded emphasis phrases. */
final class CaicaiIdleMotion {
    private float clock, attention, targetX, targetY, x, y;
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
        clock += dt;
        attention = Math.max(0, attention-dt);
        float follow = Math.min(1, attention/.55f);
        float ease = 1-(float)Math.exp(-dt/ .12f);
        x += (targetX*follow-x)*ease; y += (targetY*follow-y)*ease;
        // Each phrase has a complete entry/exit. Alternate direction and shape,
        // without a repeating pendulum or a discontinuous pulse reset.
        int phrase = (int)(clock/6.3f);
        float phase = clock%6.3f;
        float pulse = phase < 2.5f ? (float)Math.pow(Math.sin(Math.PI*phase/2.5f),2) : 0;
        float side = phrase%2 == 0 ? 1 : -1;
        float head = wave(clock*.65f,.4f)*17 + side*pulse*9;
        float pitch = wave(clock*.62f,1.9f)*12 + pulse*(phrase%3 == 0 ? 10 : -6);
        float tilt = wave(clock*.55f,3.2f)*9 + side*pulse*7;
        put(out,"ParamAngleX3", head*(1-.55f*follow)+x*22);
        put(out,"ParamAngleY2", pitch*(1-.55f*follow)+y*16);
        put(out,"ParamAngleZ",tilt); put(out,"ParamAngleZ2",tilt);
        put(out,"ParamBodyAngleX",wave(clock*.45f,.7f)*7+side*pulse*2);
        put(out,"ParamBodyAngleY",wave(clock*.50f,2.2f)*5+pulse*(phrase%3 == 1 ? 3 : -2));
        put(out,"ParamBodyAngleZ",wave(clock*.48f,4.2f)*7-side*pulse*2);
        // Eye motion remains separate from head lean; touch has immediate priority.
        put(out,"ParamEyeBallX",x*.85f+wave(clock*.6f,1)*.20f*(1-follow));
        put(out,"ParamEyeBallY",y*.8f+wave(clock*.5f,2)*.15f*(1-follow));
    }
    void applyAttention(CaicaiParameterPlan.Target out) {
        float weight=Math.min(1,attention/.55f);
        if(weight <= 0) return;
        for(String id : new String[]{"ParamAngleX3","ParamAngleY2","ParamEyeBallX","ParamEyeBallY"}) {
            float value=id.equals("ParamAngleX3") ? x*22 : id.equals("ParamAngleY2") ? y*16
                : id.equals("ParamEyeBallX") ? x*.85f : y*.8f;
            if(out.accepts(id)) out.write(id,out.current(id)*(1-weight)+value*weight);
        }
    }
    private static void put(CaicaiParameterPlan.Target out,String id,float value) {
        if(out.accepts(id)) out.write(id,value);
    }
}
