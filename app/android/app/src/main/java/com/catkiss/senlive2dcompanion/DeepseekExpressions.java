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
    private String emotion="normal",face="",wink="",comic="";
    private final Set<String> effects=new LinkedHashSet<>();
    private final Set<String> selectedEffects=new LinkedHashSet<>();
    private boolean speaking;
    static final Set<String> EYE_STYLES=new HashSet<>(Arrays.asList("圈圈眼","爱心眼","><眼","嫌弃眼"));
    private float remaining,age,weight,emotionRoll;
    void emotion(String value) {emotion=value;}
    void begin(DeepseekParameterPlan.Target target) {
        // A new event enters from the displayed (possibly fading) face, not the old
        // unweighted peak retained by this smoothing layer.
        current.clear();
        emotionRoll=0;
        for(String id:emotionPose("normal").keySet()) if(target.accepts(id)) current.put(id,target.current(id));
    }
    void trigger(String face,String wink,String effect) {
        trigger(face,wink,Arrays.asList(effect),"");
    }
    void trigger(String face,String wink,Collection<String> extras,String comic) {
        this.face=BUTTONS.containsKey(face)?face:"";
        this.wink=Arrays.asList("左wink","右wink","吐舌wink").contains(wink)?wink:"";
        this.comic="装懂小老师".equals(comic)?comic:"";
        effects.clear();selectedEffects.clear();
        if(extras!=null) for(String effect:extras)
            if(BUTTONS.containsKey(effect) && !EYE_STYLES.contains(effect)) selectedEffects.add(effect);
        if(!this.comic.isEmpty()) selectedEffects.add("兔牙");
        effects.addAll(selectedEffects);
        if(this.wink.equals("吐舌wink")) effects.remove("兔牙");
        // A single special eye appearance still composes with authored eyelids and brows.
        remaining=4.12f;age=0;
    }
    void release() {remaining=0;}
    void clearTransient() {face=wink=comic="";effects.clear();selectedEffects.clear();remaining=age=weight=0;}
    boolean active() {return remaining>0 || weight>.001f;}
    boolean reservesEyes() {return reservesEyes(false);}
    boolean reservesEyes(boolean speaking) {return reservedEyeMask()!=0;}
    int reservedEyeMask() {
        return weight>.001f && !wink.isEmpty() && age<(wink.equals("吐舌wink")?1.6f:1.2f)
            ?(wink.equals("右wink")?2:1):0;
    }
    void apply(float dt,boolean small,DeepseekParameterPlan.Target target) {
        apply(dt,small,target,1);
    }
    void apply(float dt,boolean small,DeepseekParameterPlan.Target target,float emotionWeight) {
        Map<String,Float> wanted=emotionPose(emotion);
        Map<String,Float> neutral=small?smallNeutral():emotionPose("normal");
        if(small && emotion.equals("normal")) wanted=new LinkedHashMap<>(neutral);
        // Small-form dissatisfaction has its own brows/mouth; ordinary neutral must not erase it.
        if(small) {
            wanted.put("ParamMouthForm",-1f);
            wanted.put("ParamBrowLY",Math.min(-.48f,wanted.getOrDefault("ParamBrowLY",0f)));
            wanted.put("ParamBrowRY",Math.min(-.48f,wanted.getOrDefault("ParamBrowRY",0f)));
            wanted.put("CheeckPuff",Math.max(.3f,wanted.getOrDefault("CheeckPuff",0f)));
            // Neutral is already a half-disgust blend, not a semantic emotion label.
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
        // Caicai's emotion template includes a head accent. Add it to current
        // idle instead of replacing that layer with a fixed head pose.
        emotionRoll+=(emotionRoll(emotion)-emotionRoll)*mix;
        if(target.accepts("AngleZ")) target.write("AngleZ",DeepseekParameterPlan.spatialValue(
            "AngleZ",target.current("AngleZ")+emotionRoll*emotionMix));
        remaining=Math.max(0,remaining-dt);age+=dt;
        weight+=( (remaining>0?1:0)-weight)*(1-(float)Math.exp(-dt*10));
    }
    void smallReaction(DeepseekParameterPlan.Target target) {
        for(String id:Arrays.asList("ParamMouthForm","ParamBrowLY","ParamBrowRY"))
            target.write(id,Math.min(target.current(id),applied.getOrDefault(id,0f)));
        target.write("CheeckPuff",Math.max(target.current("CheeckPuff"),applied.getOrDefault("CheeckPuff",0f)));
    }
    // Only conflicting eye appearances are exclusive; lids, brows and mouth remain composable.
    void overlay(DeepseekParameterPlan.Target target) {overlay(target,false);}
    void overlay(DeepseekParameterPlan.Target target,boolean speaking) {
        this.speaking=speaking;
        for(Map.Entry<String,String> button:BUTTONS.entrySet()) if(target.accepts(button.getValue())) {
            boolean selected=button.getKey().equals(face) || effects.contains(button.getKey());
            target.write(button.getValue(),!(speaking && button.getKey().equals("嫌弃眼")) && selected?weight:0);
        }
        if(weight<.001f) return;
        if(!comic.isEmpty()) {
            Map<String,Float> playful=emotionPose("confident");
            for(String id:Arrays.asList("ParamMouthForm","MouthFunnel","MouthPuckerWiden","MouthX",
                "ParamBrowLY","ParamBrowRY","REyeSquint","LEyeSquint"))
                if(target.accepts(id)) target.write(id,target.current(id)+(playful.get(id)-target.current(id))*weight);
        }
        if(!wink.isEmpty()) {
            float close=winkClosure(age,wink.equals("吐舌wink"))*weight;
            String eye=wink.equals("右wink")?"ParamEyeROpen":"ParamEyeLOpen";
            target.write(eye,target.current(eye)*(1-close));
            target.write(wink.equals("右wink")?"REyeSquint":"LEyeSquint",close);
            if(wink.equals("吐舌wink")) target.write("TongueOut",close>.35f?1:0);
        }
    }
    // Transient accessory overlay never mutates appearance preferences. Latest manual choice wins on release.
    void accessory(DeepseekParameterPlan.Target target) {
        if(!comic.isEmpty() && weight>.001f && target.accepts("key11"))
            target.write("key11",target.current("key11")+(1-target.current("key11"))*weight);
    }
    boolean effect(String name) {return weight>.01f && (name.equals(face) || effects.contains(name));}
    String trace() {
        Set<String> effective=new LinkedHashSet<>(effects);
        if(weight<=.001f) effective.clear();
        return emotion+" selected_face="+face+" effective_face="+(weight>.001f && !(speaking && face.equals("嫌弃眼"))?face:"")+
            " selected_effects="+selectedEffects+" effective_effects="+effective+" selected_wink="+wink+" effective_wink="+
            (weight>.001f && age<(wink.equals("吐舌wink")?1.6f:1.2f)?wink:"")+" comic="+comic+
            " suppressed="+(selectedEffects.contains("兔牙") && !effects.contains("兔牙")?"rabbit_teeth/tongue_wink":"")+
            (speaking && face.equals("嫌弃眼")?" fixed_mouth_during_audio":"")+" weight="+weight;
    }
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
    static Map<String,Float> smallNeutral() {
        Map<String,Float> base=emotionPose("normal"),disgust=emotionPose("disgust");
        base.put("ParamMouthForm",-1f);base.put("ParamMouthOpenY",0f);base.put("ParamBrowLY",-.48f);
        base.put("ParamBrowRY",-.48f);base.put("CheeckPuff",.3f);
        for(String id:Arrays.asList("ParamEyeLOpen","ParamEyeROpen","ParamBrowLY","ParamBrowRY","MouthX","EyeSmile"))
            base.put(id,base.get(id)+(disgust.get(id)-base.get(id))*.5f);
        return base;
    }
    static float emotionRoll(String emotion) {
        switch(emotion) {
            case "happy": return 4;
            case "excited": return -7;
            case "affection": return -10;
            case "shy": case "ashamed": return -12;
            case "flustered": return 10;
            case "tense": return -5;
            case "worried": return -7;
            case "confused": return -16;
            case "helpless": return -10;
            case "afraid": return 5;
            case "angry": return 7;
            case "sad": return -8;
            case "disgust": return -11;
            case "surprised": return 7;
            case "confident": return -9;
            case "playful": return 13;
            case "calm": return 2;
            default: return 0;
        }
    }
    static Map<String,Float> emotionPose(String emotion) {
        // DeepSeek has separate smile/squint, 0..1.5 opening and ear-linked brows.
        // Use authored mouth shapes off audio; PCM overrides only opening during playback.
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
        float opening=0,funnel=0,width=0,pucker=0;
        switch(emotion) {
            case "happy": opening=.22f;funnel=.25f;width=.3f;break;
            case "excited": opening=.55f;width=.65f;break;
            case "affection": opening=.10f;funnel=.12f;width=.12f;break;
            case "shy": opening=.04f;width=-.12f;break;
            case "flustered": opening=.22f;width=-.2f;break;
            case "tense": opening=.05f;width=-.25f;break;
            case "worried": opening=.06f;width=-.15f;break;
            case "helpless": opening=.08f;funnel=.10f;break;
            case "afraid": opening=.30f;width=-.4f;break;
            case "angry": opening=.06f;pucker=.25f;break;
            case "sad": opening=.10f;width=-.2f;break;
            case "disgust": opening=.04f;funnel=.12f;width=-.15f;break;
            case "serious": width=-.1f;break;
            case "surprised": opening=.45f;width=-.5f;break;
            case "confident": opening=.09f;funnel=.38f;width=.35f;break;
            case "playful": opening=.16f;funnel=.4f;width=.45f;break;
            case "ashamed": opening=.04f;width=-.3f;break;
            case "calm": width=.1f;break;
            case "confused": opening=.12f;width=-.2f;break;
            default: break;
        }
        pose.put("ParamMouthOpenY",opening);pose.put("MouthFunnel",funnel);
        pose.put("MouthPuckerWiden",width);pose.put("Mouthpucker",pucker);
        pose.put("JawOpen",0f);pose.put("TongueOut",0f);
        pose.put("ParamBrowLY",brow);pose.put("ParamBrowRY",emotion.equals("confused")?-.65f:emotion.equals("confident")?.45f:emotion.equals("playful")?.55f:brow);
        pose.put("REyeSquint",squint);pose.put("LEyeSquint",emotion.equals("playful")?.6f:squint);
        pose.put("EyeSmile",emotion.equals("angry")?-.7f:emotion.equals("disgust")?-.45f:squint);
        pose.put("BrowInnerUp",inner);pose.put("ParamEyeLOpen",open);pose.put("ParamEyeROpen",open);
        return pose;
    }
}
