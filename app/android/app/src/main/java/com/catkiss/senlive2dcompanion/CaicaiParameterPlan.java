package com.catkiss.senlive2dcompanion;

import java.util.*;
import org.json.*;

/** Sparse absolute keyframes following SoulLink's plan contract. The live lower layer is
 * sampled every frame: omitted/finished channels fade back to current idle, not zero. */
final class CaicaiParameterPlan {
    interface Target {
        boolean accepts(String id);
        float current(String id);
        void write(String id, float value);
    }
    private static final Set<String> CHANNELS = new HashSet<>(Arrays.asList(
        "ParamAngleX3", "ParamAngleY2", "ParamAngleZ", "ParamAngleZ2",
        "ParamBodyAngleX", "ParamBodyAngleY", "ParamBodyAngleZ",
        "ParamEyeBallX", "ParamEyeBallY", "ParamEyeLOpen", "ParamEyeROpen",
        "ParamEyeLSmile", "ParamEyeRSmile", "ParamBrowLY", "ParamBrowRY",
        "ParamMouthForm", "MOUTHX", "SHRUG", "OUT"));
    static boolean supports(String id) { return CHANNELS.contains(id); }
    private static final class Frame {
        float time, duration;
        Map<String, Float> values = new LinkedHashMap<>();
    }
    private final List<Frame> frames = new ArrayList<>();
    private final Map<String, Float> previous = new HashMap<>();
    private float elapsed;
    void clear() { frames.clear(); previous.clear(); elapsed = 0f; }
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
                if (supports(id) && Float.isFinite(value)) f.values.put(id, value);
            }
            lastTime = f.time;
            frames.add(f);
        }
    }
    void apply(float delta, Target target) {
        if (frames.isEmpty()) return;
        elapsed += Math.max(0f, delta);
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
        float smoothing = 1f - (float)Math.exp(-Math.max(0f, delta) * 5f / Math.max(.1f, current.duration));
        for (String id : keys) {
            if (!target.accepts(id)) { previous.remove(id); continue; }
            float lower = target.current(id);
            float old = previous.containsKey(id) ? previous.get(id) : lower;
            float wanted = finishing ? lower : current.values.getOrDefault(id, lower);
            float value = old + (wanted - old) * smoothing;
            target.write(id, value);
            previous.put(id, value);
        }
        if (elapsed > end + .65f) clear();
    }
}
