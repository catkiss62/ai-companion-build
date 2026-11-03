package com.catkiss.senlive2dcompanion;

/** Final-pose eye contact only. Never reduces authored head/body movement. */
final class DeepseekViewerFocus {
    private float weight;
    void reset() {weight=0;}
    float weight() {return weight;}
    void apply(float dt,DeepseekParameterPlan.Target pose,boolean active,boolean blocked) {
        if(blocked) {reset();return;}
        float wanted=active?1:0;
        weight+=(wanted-weight)*(1-(float)Math.exp(-Math.max(0,dt)/(active?.18f:.28f)));
        if(weight<.0001f) {weight=0;return;}
        // Iris zero follows the turned face. Counter the composed head, including
        // pointer and physics, to keep the viewer as the conversational target.
        mix(pose,"ParamEyeBallX",clamp(-pose.current("AngleX")/30*.65f,.65f));
        mix(pose,"ParamEyeBallY",clamp(-pose.current("AngleY")/30*.5f,.5f));
    }
    private void mix(DeepseekParameterPlan.Target pose,String id,float value) {
        if(pose.accepts(id)) pose.write(id,pose.current(id)+(value-pose.current(id))*weight);
    }
    private static float clamp(float value,float max) {return Math.max(-max,Math.min(max,value));}
}
