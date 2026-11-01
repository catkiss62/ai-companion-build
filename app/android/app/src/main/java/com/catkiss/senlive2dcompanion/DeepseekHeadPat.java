package com.catkiss.senlive2dcompanion;

import java.util.*;

/** Hold/release comfort and a protected puzzled easter egg, authored in DeepSeek controls. */
final class DeepseekHeadPat {
    private static final String[] FACE={"ParamEyeLOpen","ParamEyeROpen","LEyeSquint","REyeSquint",
        "EyeSmile","ParamBrowLY","ParamBrowRY","BrowInnerUp","ParamMouthForm","MouthX","CheeckPuff",
        "key1","key2","key3","key4","key5","key6","key7","key8","key9","key10","key13"};
    private static final String[] SPATIAL={"AngleX","AngleY","AngleZ","PositionX","PositionY","PositionZ",
        "LeanInput","@rootX","@rootTilt"};
    private final Map<String,Float> from=new HashMap<>();
    private boolean active,held,rare;
    private float age,release=-1;
    boolean start(boolean hold,boolean easter,DeepseekParameterPlan.Target pose) {
        if(active && rare && age<2.8f || active && held && hold && !easter) return false;
        from.clear();for(String id:FACE) if(pose.accepts(id)) from.put(id,pose.current(id));
        for(String id:SPATIAL) if(pose.accepts(id)) from.put(id,pose.current(id));
        active=true;held=hold&&!easter;rare=easter;age=0;release=-1;return true;
    }
    void release() {held=false;if(active&&!rare&&release<0) release=0;}
    void cancel() {active=held=false;from.clear();}
    boolean active() {return active;}
    String state() {return !active?"idle":rare?"easter_egg":held?"held":"releasing";}
    void apply(float dt,boolean small,DeepseekParameterPlan.Target pose) {
        if(!active || dt<=0) return;
        age+=dt;if(!held&&!rare&&release<0&&age>=1.1f) release=0;
        if(release>=0) release+=dt;
        float in=smooth(age/.35f),out=rare?smooth((age-2.2f)/.6f):release<0?0:smooth(release/.55f);
        for(String id:FACE) if(pose.accepts(id)) {
            float target=0;
            switch(id) {
                case "ParamEyeLOpen":target=rare?.65f:.12f;break;
                case "ParamEyeROpen":target=rare?1.05f:.12f;break;
                case "LEyeSquint":case "REyeSquint":target=rare?0:.9f;break;
                case "EyeSmile":target=rare?0:.65f;break;
                case "ParamBrowLY":target=rare?-.5f:small?-.18f:.22f;break;
                case "ParamBrowRY":target=rare?.65f:small?-.18f:.22f;break;
                case "BrowInnerUp":target=rare?.35f:0;break;
                case "ParamMouthForm":target=rare?-.3f:small?-.7f:.65f;break;
                case "MouthX":target=rare?.4f:0;break;
                case "CheeckPuff":target=small?.28f:0;break;
                case "key7":target=rare?0:.25f;break;
                default:break;
            }
            float entered=from.getOrDefault(id,pose.current(id))*(1-in)+target*in;
            pose.write(id,entered*(1-out)+pose.current(id)*out);
        }
        for(String id:SPATIAL) if(pose.accepts(id)) {
            float base=pose.current(id),target=base;
            if(id.equals("AngleY")) target-=3.5f;
            if(id.equals("AngleZ")) target+=rare?-5:2*(float)Math.sin(age*4);
            if(id.equals("PositionY")) target-=.8f;
            float entered=from.getOrDefault(id,base)*(1-in)+target*in;
            float value=entered*(1-out)+base*out;
            float cap=id.startsWith("Angle")?14:id.startsWith("Position")?8:id.equals("@rootX")?.035f:id.equals("@rootTilt")?3:30;
            pose.write(id,Math.max(-cap,Math.min(id.equals("LeanInput")?0:cap,value)));
        }
        if(out>=1 || rare&&age>=2.8f) {active=false;from.clear();}
    }
    private static float smooth(float x) {x=Math.max(0,Math.min(1,x));return x*x*(3-2*x);}
}
