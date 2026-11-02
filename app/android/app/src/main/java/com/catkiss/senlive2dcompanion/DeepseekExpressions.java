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
    private final Map<String,Float> applied=new HashMap<>();
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
    void clearTransient() {face=wink=effect="";remaining=age=weight=0;}
    boolean active() {return remaining>0 || weight>.001f;}
    boolean reservesEyes() {
        return weight>.001f && (Arrays.asList("圈圈眼","爱心眼","><眼","嫌弃眼").contains(face)
            || !wink.isEmpty() && age<(wink.equals("吐舌wink")?1.6f:1.2f));
    }
    void apply(float dt,boolean small,DeepseekParameterPlan.Target target) {
        apply(dt,small,target,1);
    }
    void apply(float dt,boolean small,DeepseekParameterPlan.Target target,float emotionWeight) {
        Map<String,Float> wanted=emotionPose(emotion);
        Map<String,Float> neutral=emotionPose("normal");
        // Small-form dissatisfaction has its own brows/mouth; ordinary neutral must not erase it.
        if(small) {
            wanted.put("ParamMouthForm",-1f);
            wanted.put("ParamBrowLY",Math.min(-.48f,wanted.getOrDefault("ParamBrowLY",0f)));
            wanted.put("ParamBrowRY",Math.min(-.48f,wanted.getOrDefault("ParamBrowRY",0f)));
            wanted.put("CheeckPuff",Math.max(.3f,wanted.getOrDefault("CheeckPuff",0f)));
            neutral.put("ParamMouthForm",-1f);neutral.put("ParamBrowLY",-.48f);
            neutral.put("ParamBrowRY",-.48f);neutral.put("CheeckPuff",.3f);
        }
        Set<String> keys=new HashSet<>(current.keySet());keys.addAll(wanted.keySet());
        float mix=1-(float)Math.exp(-Math.max(0,dt)*8);
        float emotionMix=Float.isFinite(emotionWeight)?Math.max(0,Math.min(1,emotionWeight)):0;
        for(String id:keys) {
            float v=current.getOrDefault(id,target.current(id));v+=(wanted.getOrDefault(id,target.current(id))-v)*mix;
            current.put(id,v);
            float base=neutral.getOrDefault(id,target.current(id)),shown=base+(v-base)*emotionMix;
            applied.put(id,shown);if(target.accepts(id)) target.write(id,shown);
        }
        remaining=Math.max(0,remaining-dt);age+=dt;
        weight+=( (remaining>0?1:0)-weight)*(1-(float)Math.exp(-dt*10));
    }
    void smallReaction(DeepseekParameterPlan.Target target) {
        for(String id:Arrays.asList("ParamMouthForm","ParamBrowLY","ParamBrowRY"))
            target.write(id,Math.min(target.current(id),applied.getOrDefault(id,0f)));
        target.write("CheeckPuff",Math.max(target.current("CheeckPuff"),applied.getOrDefault("CheeckPuff",0f)));
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
        // DeepSeek has separate smile/squint, 0..1.5 opening and ear-linked brows.
        // Use that range for readable emotion; no special eye buttons or PCM opening here.
        float mouth=0,brow=0,squint=0,open=1,inner=0,x=0,puff=0;
        switch(emotion) {
            case "happy": mouth=1;brow=.35f;squint=.85f;break;
            case "excited": mouth=1;brow=.85f;squint=1;open=1.2f;break;
            case "affection": mouth=.85f;brow=.25f;squint=.8f;open=.9f;break;
            case "shy": mouth=.55f;brow=.35f;squint=.6f;x=-.6f;open=.85f;break;
            case "flustered": mouth=-.65f;brow=.85f;open=1.35f;inner=.5f;x=.45f;break;
            case "tense": mouth=-.65f;brow=-.65f;open=1.15f;break;
            case "worried": mouth=-.8f;brow=.65f;inner=.9f;open=.85f;x=-.35f;break;
            case "helpless": mouth=-.65f;brow=.45f;squint=.25f;open=.7f;x=-.5f;break;
            case "afraid": mouth=-.85f;brow=.95f;inner=1;open=1.4f;break;
            case "angry": mouth=-1;brow=-1;open=.85f;puff=.75f;break;
            case "sad": mouth=-1;brow=.8f;inner=1;open=.65f;break;
            case "disgust": mouth=-.85f;brow=-.6f;open=.55f;x=.8f;break;
            case "serious": mouth=-.5f;brow=-.55f;open=.9f;break;
            case "surprised": mouth=-.6f;brow=1;open=1.5f;inner=.4f;break;
            case "confident": mouth=.85f;brow=-.2f;squint=.45f;x=.75f;break;
            case "playful": mouth=1;brow=-.25f;squint=.9f;x=.8f;break;
            case "ashamed": mouth=-.8f;brow=.45f;squint=.8f;inner=.5f;open=.8f;x=-.55f;break;
            case "calm": mouth=.4f;brow=.1f;squint=.35f;break;
            case "confused": mouth=-.25f;brow=.9f;inner=.6f;open=1.2f;x=.75f;break;
            default: break;
        }
        Map<String,Float> pose=new LinkedHashMap<>();
        pose.put("ParamMouthForm",mouth);pose.put("MouthX",x);pose.put("CheeckPuff",puff);
        pose.put("ParamBrowLY",brow);pose.put("ParamBrowRY",emotion.equals("confused")?-.65f:emotion.equals("confident")?.45f:emotion.equals("playful")?.55f:brow);
        pose.put("REyeSquint",squint);pose.put("LEyeSquint",emotion.equals("playful")?.6f:squint);
        pose.put("EyeSmile",emotion.equals("angry")?-.7f:emotion.equals("disgust")?-.45f:squint);
        pose.put("BrowInnerUp",inner);pose.put("ParamEyeLOpen",open);pose.put("ParamEyeROpen",open);
        return pose;
    }
}
