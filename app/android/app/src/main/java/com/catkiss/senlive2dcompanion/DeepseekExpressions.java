package com.catkiss.senlive2dcompanion;

import java.util.*;

/** Absolute independent face layers. No raw additive exp3 replay or outfit resets. */
final class DeepseekExpressions {
    static final Set<String> MOUTH=Collections.unmodifiableSet(new HashSet<>(Arrays.asList(
        "ParamMouthForm","ParamMouthOpenY","JawOpen","TongueOut","MouthX","Mouthpucker",
        "MouthFunnel","MouthPuckerWiden","CheeckPuff")));
    static final Map<String,String> BUTTONS;
    static {
        Map<String,String> b=new LinkedHashMap<>();
        b.put("黑脸","key1");b.put("落泪","key2");b.put("圈圈眼","key3");b.put("爱心眼","key4");
        b.put("><眼","key5");b.put("嫌弃眼","key6");b.put("脸红","key7");b.put("加载","key8");
        b.put("兔牙","key9");b.put("大钢盆","key10");b.put("流冷汗","key13");
        BUTTONS=Collections.unmodifiableMap(b);
    }
    private final Map<String,Float> current=new HashMap<>();
    private String emotion="normal",face="",wink="",effect="";
    private float remaining,age,weight;
    void emotion(String value) {emotion=value;}
    void trigger(String face,String wink,String effect) {
        this.effect=BUTTONS.containsKey(effect) && !Arrays.asList("圈圈眼","爱心眼","><眼","嫌弃眼").contains(effect)?effect:"";
        this.face=BUTTONS.containsKey(face)?face:"";
        this.wink=Arrays.asList("左wink","右wink","吐舌wink").contains(wink)?wink:"";
        remaining=3.2f;age=0;
    }
    void release() {remaining=0;}
    void apply(float dt,boolean small,DeepseekParameterPlan.Target target) {
        Map<String,Float> wanted=emotionPose(emotion);
        // Small-form dissatisfaction has its own brows/mouth; ordinary neutral must not erase it.
        if(small) {
            wanted.put("ParamMouthForm",-1f);
            wanted.put("ParamBrowLY",Math.min(-.48f,wanted.getOrDefault("ParamBrowLY",0f)));
            wanted.put("ParamBrowRY",Math.min(-.48f,wanted.getOrDefault("ParamBrowRY",0f)));
            wanted.put("CheeckPuff",Math.max(.3f,wanted.getOrDefault("CheeckPuff",0f)));
        }
        Set<String> keys=new HashSet<>(current.keySet());keys.addAll(wanted.keySet());
        float mix=1-(float)Math.exp(-Math.max(0,dt)*8);
        for(String id:keys) {
            float v=current.getOrDefault(id,target.current(id));v+=(wanted.getOrDefault(id,target.current(id))-v)*mix;
            current.put(id,v);if(target.accepts(id)) target.write(id,v);
        }
        remaining=Math.max(0,remaining-dt);age+=dt;
        weight+=( (remaining>0?1:0)-weight)*(1-(float)Math.exp(-dt*10));
    }
    void smallReaction(DeepseekParameterPlan.Target target) {
        for(String id:Arrays.asList("ParamMouthForm","ParamBrowLY","ParamBrowRY"))
            target.write(id,Math.min(target.current(id),current.getOrDefault(id,0f)));
        target.write("CheeckPuff",Math.max(target.current("CheeckPuff"),current.getOrDefault("CheeckPuff",0f)));
    }
    // Overlay after the parameter plan, preventing simultaneous special-eye states.
    void overlay(DeepseekParameterPlan.Target target) {
        for(String id:BUTTONS.values()) if(target.accepts(id)) target.write(id,(id.equals(BUTTONS.get(face)) || id.equals(BUTTONS.get(effect)))?weight:0);
        if(weight<.001f) return;
        boolean special=Arrays.asList("圈圈眼","爱心眼","><眼","嫌弃眼").contains(face);
        if(!special && !wink.isEmpty()) {
            float close=winkClosure(age,wink.equals("吐舌wink"))*weight;
            String eye=wink.equals("右wink")?"ParamEyeROpen":"ParamEyeLOpen";
            target.write(eye,target.current(eye)*(1-close));
            target.write(wink.equals("右wink")?"REyeSquint":"LEyeSquint",close);
            if(wink.equals("吐舌wink")) target.write("TongueOut",close>.35f?1:0);
        }
    }
    boolean effect(String name) {return weight>.01f && (name.equals(face) || name.equals(effect));}
    String trace() {return emotion+" face="+face+" weight="+weight+" effect="+effect+" wink="+wink;}
    static float winkClosure(float age,boolean tongue) {
        if(!Float.isFinite(age) || age<=0) return 0;
        float duration=tongue?1.6f:1.2f;
        if(age>=duration) return 0;
        return Math.min(1,Math.min(age/.18f,(duration-age)/.36f));
    }
    static float cycle(float elapsed,float period,float min,float max) {
        if(!Float.isFinite(elapsed) || !Float.isFinite(min) || !Float.isFinite(max) || period<=0 || max<=min) return min;
        float phase=elapsed/period;phase-=(float)Math.floor(phase);
        return min+(max-min)*phase;
    }
    static Map<String,Float> emotionPose(String emotion) {
        // Mouth form, brows, squint, eye opening: authored DeepSeek semantics, not Caicai values.
        float mouth=0,brow=0,squint=0,open=1,inner=0,x=0,puff=0;
        switch(emotion) {
            case "happy": mouth=.68f;brow=.22f;squint=.38f;break;
            case "excited": mouth=.9f;brow=.62f;squint=.65f;open=1.12f;break;
            case "affection": mouth=.48f;brow=.15f;squint=.44f;break;
            case "shy": mouth=.25f;brow=.12f;squint=.28f;x=-.2f;break;
            case "flustered": mouth=-.35f;brow=.58f;open=1.22f;inner=.3f;break;
            case "tense": mouth=-.42f;brow=-.28f;open=1.08f;break;
            case "worried": mouth=-.52f;brow=.28f;inner=.65f;open=.9f;break;
            case "helpless": mouth=-.3f;brow=.12f;squint=.22f;open=.8f;break;
            case "afraid": mouth=-.6f;brow=.55f;inner=.7f;open=1.3f;break;
            case "angry": mouth=-.85f;brow=-.7f;puff=.45f;break;
            case "sad": mouth=-.72f;brow=.25f;inner=.8f;open=.75f;break;
            case "disgust": mouth=-.6f;brow=-.32f;open=.65f;x=.4f;break;
            case "serious": mouth=-.2f;brow=-.3f;break;
            case "surprised": brow=.7f;open=1.45f;inner=.2f;break;
            case "confident": mouth=.6f;brow=.05f;squint=.18f;x=.25f;break;
            case "playful": mouth=.78f;brow=.3f;squint=.45f;x=.35f;break;
            case "ashamed": mouth=-.24f;brow=.25f;squint=.35f;inner=.3f;break;
            case "calm": mouth=.15f;squint=.1f;break;
            case "confused": mouth=-.12f;inner=.4f;open=1.12f;break;
            default: break;
        }
        Map<String,Float> pose=new LinkedHashMap<>();
        pose.put("ParamMouthForm",mouth);pose.put("MouthX",x);pose.put("CheeckPuff",puff);
        pose.put("ParamBrowLY",brow);pose.put("ParamBrowRY",emotion.equals("confused")?-.4f:brow);
        pose.put("REyeSquint",squint);pose.put("LEyeSquint",squint);pose.put("EyeSmile",squint*.5f);
        pose.put("BrowInnerUp",inner);pose.put("ParamEyeLOpen",open);pose.put("ParamEyeROpen",open);
        return pose;
    }
}
