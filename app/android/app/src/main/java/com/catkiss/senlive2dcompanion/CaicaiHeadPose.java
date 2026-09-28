package com.catkiss.senlive2dcompanion;

import java.util.LinkedHashMap;
import java.util.Map;

/** The lab's HEAD_X/Y_SWEEP writes these visible rig outputs after physics.
 * All three interactive owners collect their final intention through this same layer. */
final class CaicaiHeadPose {
    private final Map<String,Float> requested=new LinkedHashMap<>();
    private final Map<String,Float> afterPhysics=new LinkedHashMap<>();
    void begin() { requested.clear(); afterPhysics.clear(); }
    void record(String id,float value) {
        if(id.equals("ParamAngleX3") || id.equals("ParamAngleY2")) requested.put(id,value);
    }
    void finish(CaicaiParameterPlan.Target target) {
        for(Map.Entry<String,Float> e:requested.entrySet()) if(target.accepts(e.getKey())) {
            afterPhysics.put(e.getKey(),target.current(e.getKey()));
            target.write(e.getKey(),e.getValue());
        }
    }
    String trace(CaicaiParameterPlan.Target target) {
        StringBuilder s=new StringBuilder();
        for(String id:requested.keySet()) s.append(id).append(":requested=").append(requested.get(id))
            .append(",afterPhysics=").append(afterPhysics.get(id)).append(",final=").append(target.current(id)).append(';');
        return s.toString();
    }
}
