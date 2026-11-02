package com.catkiss.senlive2dcompanion;

/** Eye contact for an actual lean, after plan, pointer and physics have composed the pose. */
final class DeepseekLeanFocus {
    private float weight;
    void reset() {weight=0;}
    float weight() {return weight;}
    void apply(float dt,DeepseekParameterPlan.Target pose,boolean blocked) {
        if(blocked) {reset();return;}
        float lean=Math.max(0,Math.min(1,-pose.current("LeanInput")/24f));
        float wanted=lean*lean*(3-2*lean);
        weight+=(wanted-weight)*(1-(float)Math.exp(-Math.max(0,dt)/.09f));
        if(weight<.0001f) {weight=0;return;}
        mix(pose,"AngleX",.2f);mix(pose,"AngleY",.2f);
        mix(pose,"ParamEyeBallX",0);mix(pose,"ParamEyeBallY",0);
    }
    private void mix(DeepseekParameterPlan.Target pose,String id,float remaining) {
        if(pose.accepts(id)) pose.write(id,pose.current(id)*(1-weight+remaining*weight));
    }
}
