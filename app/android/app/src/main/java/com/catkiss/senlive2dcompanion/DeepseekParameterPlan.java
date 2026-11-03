package com.catkiss.senlive2dcompanion;

import java.util.*;
import org.json.*;

/** Sparse absolute keyframes following the DeepSeek four-beat contract. The live lower layer is
 * sampled every frame: omitted/finished channels fade back to current idle, not zero. */
final class DeepseekParameterPlan {
    interface Target {
        boolean accepts(String id);
        float current(String id);
        void write(String id, float value);
    }
    private static final Set<String> CHANNELS = new HashSet<>(Arrays.asList(
        "AngleX","AngleY","AngleZ","PositionX","PositionY","PositionZ","LeanInput",
        "ParamEyeBallX","ParamEyeBallY","ParamBrowLY","ParamBrowRY","BrowInnerUp",
        "ParamEyeLOpen","ParamEyeROpen","EyeSmile","REyeSquint","LEyeSquint","ParamMouthForm","MouthX","Mouthpucker",
        "MouthFunnel","MouthPuckerWiden","CheeckPuff","TongueOut"));
    static boolean supports(String id) { return CHANNELS.contains(id); }
    // These are input parameter units, not physical degrees. Core remains the final authority.
    static float spatialValue(String id,float value) {
        float cap=id.startsWith("Angle") || id.startsWith("Position") || id.equals("LeanInput")?30:
            id.equals("@rootX")?.15f:id.equals("@rootTilt")?10:Float.POSITIVE_INFINITY;
        return Math.max(-cap,Math.min(id.equals("LeanInput")?0:cap,value));
    }
    private static final class Frame {
        float time, duration;
        Map<String, Float> values = new LinkedHashMap<>();
    }
    private final List<Frame> frames = new ArrayList<>();
    private final Map<String, Float> previous = new HashMap<>();
    private float elapsed, gain=1f, speed=1f;
    void setSpeed(float value) { speed=value; }
    void setGain(float value) { gain=value; }
    void clear() { frames.clear(); previous.clear(); elapsed = 0f; }
    boolean active() {return !frames.isEmpty();}
    boolean reservesEyes() {return active() && (previous.containsKey("ParamEyeLOpen")
        || previous.containsKey("ParamEyeROpen"));}
    void captureInitial(Target target) {
        for (Frame frame : frames) for (String id : frame.values.keySet())
            if (target.accepts(id)) previous.put(id, target.current(id));
    }
    void replace(String json, Target target) throws JSONException {
        Set<String> oldChannels = new HashSet<>(previous.keySet());
        start(json);
        captureInitial(target);
        for (String id : oldChannels) if (target.accepts(id)) previous.put(id, target.current(id));
    }
    void release() {
        if (frames.isEmpty()) return;
        float end = 0f;
        for (Frame frame : frames) end = Math.max(end, frame.time + frame.duration);
        if (elapsed <= end) elapsed = end + .001f;
    }
    void start(String json) throws JSONException {
        clear();
        JSONArray input = new JSONArray(json);
        float lastTime = -1f;
        for (int i = 0; i < Math.min(8, input.length()); i++) {
            JSONObject item = input.getJSONObject(i);
            Frame f = new Frame();
            f.time = (float)item.getDouble("time");
            f.duration = (float)item.getDouble("duration");
            if (!Float.isFinite(f.time) || !Float.isFinite(f.duration)
                || f.time < 0 || f.time < lastTime || f.time > 12 || f.duration <= 0 || f.duration > 4) continue;
            JSONObject values = item.getJSONObject("parameters");
            Iterator<String> keys = values.keys();
            while (keys.hasNext()) {
                String id = keys.next();
                float value = (float)values.optDouble(id, Double.NaN);
                value=spatialValue(id,value);
                if (supports(id) && Float.isFinite(value)) f.values.put(id, value);
            }
            // Root movement has its own namespace; never write fabricated Cubism IDs.
            JSONObject root = item.optJSONObject("root");
            if (root != null) {
                for (String key : new String[]{"x","tilt"}) {
                    float v=(float)root.optDouble(key,Double.NaN);
                    if (Float.isFinite(v)) f.values.put(key.equals("x") ? "@rootX" : "@rootTilt",
                        spatialValue(key.equals("x") ? "@rootX" : "@rootTilt",v));
                }
            }
            lastTime = f.time;
            frames.add(f);
        }
    }
    void apply(float delta, Target target) {
        if (frames.isEmpty()) return;
        delta=Math.max(0f,delta)*speed;
        elapsed += delta;
        Frame current = null;
        float end = 0f;
        for (Frame frame : frames) {
            if (frame.time <= elapsed) current = frame;
            end = Math.max(end, frame.time + frame.duration);
        }
        boolean finishing = elapsed > end;
        if (current == null) return;
        Set<String> keys = new HashSet<>(previous.keySet());
        keys.addAll(current.values.keySet());
        boolean leanSettled=true;
        for (String id : keys) {
            if (!target.accepts(id)) { previous.remove(id); continue; }
            // Head, body and whole-model travel should pass through the pose
            // instead of reaching it in a few frames. Facial cues stay quick.
            boolean spatial = id.startsWith("Angle") || id.startsWith("Position") || id.equals("LeanInput")
                || id.startsWith("@root");
            // Speaking-only horizontal travel and body X/Z should settle on
            // the cadence of idle movement; head, Y, face remain responsive.
            boolean slowAxis = id.equals("@rootX") || id.equals("PositionX")
                || id.equals("PositionZ");
            float rate=finishing?9f:(slowAxis?1.5f:spatial?3.4f:5f)/Math.max(.1f,current.duration);
            float lower = target.current(id);
            float old = previous.containsKey(id) ? previous.get(id) : lower;
            float wanted = lower;
            if (!finishing && current.values.containsKey(id)) {
                float scale=id.startsWith("Angle") || id.startsWith("Position") || id.startsWith("@root") ? gain : 1f;
                wanted=current.values.get(id)*scale;
            }
            // About .46s in / .55s out to 95%, independent of a short speech beat.
            if(id.equals("LeanInput")) rate=wanted<old?6.5f:5.5f;
            float smoothing=1f-(float)Math.exp(-delta*rate);
            float value = old + (wanted - old) * smoothing;
            if(id.equals("LeanInput")) {
                if(Math.abs(wanted-value)<.1f) value=wanted;
                leanSettled=Math.abs(wanted-value)<.1f;
            }
            value=spatialValue(id,value);
            target.write(id, value);
            previous.put(id, value);
        }
        if (elapsed > end + .65f && (leanSettled || elapsed > end + 1.5f)) clear();
    }
}
