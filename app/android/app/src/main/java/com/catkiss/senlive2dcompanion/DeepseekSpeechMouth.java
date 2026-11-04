package com.catkiss.senlive2dcompanion;

import java.util.*;

/** PCM owns opening and centers the mouth; expression layers retain smile, width and cheeks. */
final class DeepseekSpeechMouth {
    private static final String[] SHAPES={"ParamMouthForm","Mouthpucker","MouthFunnel",
        "MouthPuckerWiden","CheeckPuff","TongueOut"};
    private final Map<String,Float> shapes=new HashMap<>();
    void capture(DeepseekParameterPlan.Target pose) {
        shapes.clear();
        for(String id:SHAPES) if(pose.accepts(id)) shapes.put(id,pose.current(id));
    }
    void restore(DeepseekParameterPlan.Target pose) {
        for(Map.Entry<String,Float> e:shapes.entrySet()) pose.write(e.getKey(),e.getValue());
    }
    static float opening(float amplitude) {
        return Float.isFinite(amplitude)?Math.max(0,Math.min(1,amplitude*1.2f)):0;
    }
    static void apply(float amplitude,DeepseekParameterPlan.Target pose) {
        apply(amplitude,pose,0);
    }
    static void apply(float amplitude,DeepseekParameterPlan.Target pose,float neutralX) {
        float open=opening(amplitude);
        pose.write("MouthX",Float.isFinite(neutralX)?neutralX:0);
        pose.write("key6",0); // The user's fixed-mouth contempt button is opening-only.
        pose.write("ParamMouthOpenY",open);
        pose.write("JawOpen",0); // An independent jaw opening must not defeat silent phonemes.
        if(open==0) pose.write("MouthFunnel",0);
    }
}
