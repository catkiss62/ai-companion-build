package com.catkiss.senlive2dcompanion;

import java.util.HashMap;
import java.util.Map;

/** Sen's hold/release/easter-egg interaction, in the maid's visible parameter space.
 * Blend from the rendered face; gaze and idle continue as live lower layers. */
final class CaicaiHeadPat {
    private static final String[] FACE={"ParamEyeLOpen","ParamEyeROpen","ParamEyeLSmile",
        "ParamEyeRSmile","ParamBrowLY","ParamBrowRY","ParamMouthForm","MOUTHX"};
    private final Map<String,Float> from=new HashMap<>();
    private boolean active, held, confused;
    private float age, releaseAge=-1;
    void start(boolean hold, boolean rare, CaicaiParameterPlan.Target pose) {
        from.clear(); for(String id:FACE) if(pose.accepts(id)) from.put(id,pose.current(id));
        active=true; held=hold && !rare; confused=rare; age=0; releaseAge=-1;
    }
    void release() { held=false; if(active && !confused && releaseAge<0) releaseAge=0; }
    void cancel() { active=false; held=false; }
    boolean active() { return active; }
    String state() { return !active ? "idle" : confused ? "easter_egg" : held ? "held" : "releasing"; }
    float followWeight() { return active ? .25f : 1f; }
    void apply(float dt, CaicaiParameterPlan.Target pose) {
        if(!active || dt<=0) return;
        age+=dt;
        if(!held && !confused && releaseAge<0 && age>=1.1f) releaseAge=0;
        if(releaseAge>=0) releaseAge+=dt;
        float in=smooth(Math.min(1,age/.38f));
        float out=confused ? smooth(Math.max(0,(age-2.2f)/.6f))
            : releaseAge<0 ? 0 : smooth(Math.min(1,releaseAge/.55f));
        float weight=in*(1-out);
        for(String id:FACE) {
            if(!pose.accepts(id)) continue;
            float target;
            switch(id) {
                case "ParamEyeLOpen": target=confused ? .65f : .15f; break;
                case "ParamEyeROpen": target=confused ? 1f : .15f; break;
                case "ParamEyeLSmile": case "ParamEyeRSmile": target=confused ? 0 : .95f; break;
                case "ParamBrowLY": target=confused ? -.5f : .25f; break;
                case "ParamBrowRY": target=confused ? .8f : .25f; break;
                case "ParamMouthForm": target=confused ? -.25f : .85f; break;
                default: target=confused ? .65f : 0;
            }
            float entered=from.getOrDefault(id,pose.current(id))*(1-in)+target*in;
            pose.write(id,entered*(1-out)+pose.current(id)*out);
        }
        add(pose,"ParamAngleY2",-12*weight);
        add(pose,"ParamAngleZ",(confused?-12:6*(float)Math.sin(age*5))*weight);
        add(pose,"ParamAngleZ2",(confused?-12:6*(float)Math.sin(age*5))*weight);
        if(out>=1) active=false;
    }
    private static float smooth(float x) { x=Math.max(0,Math.min(1,x)); return x*x*(3-2*x); }
    private static void add(CaicaiParameterPlan.Target p,String id,float v) {
        if(p.accepts(id)) p.write(id,p.current(id)+v);
    }
}
