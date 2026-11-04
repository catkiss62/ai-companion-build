package com.catkiss.senlive2dcompanion;

import java.util.*;

/** PCM owns opening and centers the mouth; expression layers retain smile and cheeks.
 * Acoustic width is an additive hint on the expressive width, never a replacement face. */
final class DeepseekSpeechMouth {
    private static final String[] SHAPES={"ParamMouthForm","Mouthpucker","MouthFunnel",
        "MouthPuckerWiden","CheeckPuff","TongueOut"};
    private final Map<String,Float> shapes=new HashMap<>();
    private float targetWidth,width,targetOpening=1,opening=1;
    private long signalAt;
    void signal(float newWidth,float newOpening,long now) {
        targetWidth=Float.isFinite(newWidth)?Math.max(-.55f,Math.min(.45f,newWidth)):0;
        targetOpening=Float.isFinite(newOpening)?Math.max(.78f,Math.min(1.12f,newOpening)):1;
        signalAt=now;
    }
    void resetSignal() {targetWidth=width=0;targetOpening=opening=1;signalAt=0;}
    /** Advance exactly once per rendered frame, not on both sides of physics. */
    void advance(float delta,boolean playing,long now) {
        if(!playing) {resetSignal();return;}
        if(signalAt==0 || now-signalAt>200_000_000L) {targetWidth=0;targetOpening=1;}
        float t=Float.isFinite(delta)?Math.max(0,Math.min(.1f,delta)):0;
        float blend=1-(float)Math.exp(-t/.055f);
        width+=(targetWidth-width)*blend;opening+=(targetOpening-opening)*blend;
    }
    void applyFrame(float amplitude,DeepseekParameterPlan.Target pose,float neutralX) {
        apply(amplitude,pose,neutralX);
        float open=opening(amplitude);
        if(open==0 || pose.current("TongueOut")>.1f) return;
        pose.write("ParamMouthOpenY",Math.min(1,open*opening));
        // Fade shape hints at quiet consonants. Do not turn a pout/teeth slit,
        // tongue wink, saved cat-mouth style or emotional smile into a vowel.
        float amount=Math.min(1,open*5);
        if(pose.accepts("MouthPuckerWiden")) pose.write("MouthPuckerWiden",
            Math.max(-1,Math.min(1,pose.current("MouthPuckerWiden")+width*amount)));
    }
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
