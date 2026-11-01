package com.catkiss.senlive2dcompanion;

import java.util.*;

/** One arm owner: authored enter, bounded hold, authored return, smooth interruption. */
final class DeepseekGestures {
    private static final String AMBIENT="__idle_grass";
    static final Set<String> IDLE_CHANNELS=Collections.unmodifiableSet(new HashSet<>(Arrays.asList(
        "Movement1","Param36","Param39","Param41","Param42","Param43")));
    static final Set<String> CHANNELS=Collections.unmodifiableSet(new HashSet<>(Arrays.asList(
        "Movement1","Movement2","Movement3","Param40","Param36","Param39","Param41","Param42","Param43",
        "Param62","Param59","Param60","Param61")));
    private final Map<String,DeepseekMotionClip[]> clips=new HashMap<>();
    private final Map<String,Float> pose=new LinkedHashMap<>(), from=new LinkedHashMap<>();
    private String active="",pending="",phase="idle";
    private float elapsed,hold=2;
    void register(String name,DeepseekMotionClip enter,DeepseekMotionClip exit) { clips.put(name,new DeepseekMotionClip[]{enter,exit}); }
    void registerAmbient(DeepseekMotionClip enter,DeepseekMotionClip exit) {register(AMBIENT,enter,exit);}
    boolean requestAmbient() {return !busy() && begin(AMBIENT,.4f);}
    boolean ambientActive() {return active.equals(AMBIENT);}
    boolean busy() {return !active.isEmpty();}
    void clear() {active=pending="";phase="idle";elapsed=0;pose.clear();from.clear();}
    boolean request(String name,float holdSeconds) {
        return !name.equals(AMBIENT) && begin(name,holdSeconds);
    }
    private boolean begin(String name,float holdSeconds) {
        if(!clips.containsKey(name)) return false;
        hold=Math.max(.4f,Math.min(6,holdSeconds));
        if(active.equals(name) && !phase.equals("exit")) return true;
        if(!active.isEmpty()) {pending=name;release();return true;}
        active=name;phase="enter";elapsed=0;from.clear();from.putAll(pose);return true;
    }
    void release() {
        if(active.isEmpty() || phase.equals("exit")) return;
        phase="exit";elapsed=0;from.clear();from.putAll(pose);
    }
    void stop() {pending="";release();}
    Map<String,Float> update(float delta) {
        if(active.isEmpty()) return Collections.emptyMap();
        elapsed+=Math.max(0,delta);
        DeepseekMotionClip[] pair=clips.get(active);
        if(phase.equals("hold")) {
            if(elapsed>=hold) {phase="exit";elapsed=0;from.clear();from.putAll(pose);}
            else return pose;
        }
        boolean exit=phase.equals("exit");DeepseekMotionClip clip=pair[exit?1:0];
        Map<String,Float> sampled=clip.sample(elapsed);
        float mix=Math.min(1,elapsed/.22f);mix=mix*mix*(3-2*mix);
        Map<String,Float> first=exit?clip.sample(0):Collections.emptyMap();
        Map<String,Float> last=exit?clip.sample(clip.duration):Collections.emptyMap();
        for(String id:CHANNELS) {
            float initial=from.getOrDefault(id,0f),value=sampled.getOrDefault(id,0f);
            if(exit) {
                float begin=first.getOrDefault(id,0f),end=last.getOrDefault(id,0f);
                float progress=Math.abs(end-begin)<.00001f?Math.min(1,elapsed/clip.duration):
                    Math.max(0,Math.min(1,(value-begin)/(end-begin)));
                // Retarget the authored return from the interrupted pose, not from a raised arm.
                pose.put(id,initial*(1-progress));
            } else pose.put(id,initial+(value-initial)*mix);
        }
        if(elapsed>=clip.duration) {
            if(!exit) {phase="hold";elapsed=0;}
            else {
                // Exact neutral on completion; never keep an authored near-zero wrist drift.
                pose.replaceAll((id,v)->0f);active="";phase="idle";elapsed=0;
                if(!pending.isEmpty()) {String next=pending;pending="";request(next,hold);}
            }
        }
        return pose;
    }
    String trace() {return active+":"+phase+" available="+clips.keySet();}
}
