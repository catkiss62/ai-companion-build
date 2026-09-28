package com.catkiss.senlive2dcompanion;

import java.util.ArrayDeque;
import java.util.function.Supplier;
import org.json.JSONArray;
import org.json.JSONObject;

/** At most 180 one-second snapshots, in memory only. No models, pixels or chat text. */
final class CaicaiFrameDiagnostics {
    private final ArrayDeque<String> samples=new ArrayDeque<>();
    private long windowStart,lastDraw,lastModelDraw;
    private int windowFrames;
    private double fps;
    synchronized void frame(long now,boolean modelDraw,Supplier<String> trace) {
        lastDraw=now; if(modelDraw) lastModelDraw=now;
        if(windowStart==0) windowStart=now;
        windowFrames++;
        long duration=now-windowStart;
        if(duration<1_000_000_000L) return;
        fps=windowFrames*1_000_000_000.0/duration;
        samples.addLast("uptimeMs="+(now/1_000_000L)+" fps="+Math.round(fps*10)/10.0
            +" modelDraw="+modelDraw+" "+trace.get());
        while(samples.size()>180) samples.removeFirst();
        windowStart=now; windowFrames=0;
    }
    synchronized String summary() {
        long now=System.nanoTime();
        return "targetFps=60 maskPx=512 fps="+Math.round(fps*10)/10.0
            +" drawAgeMs="+age(now,lastDraw)+" modelDrawAgeMs="+age(now,lastModelDraw);
    }
    private static long age(long now,long then) { return then==0 ? -1 : (now-then)/1_000_000L; }
    synchronized String export() {
        try { return new JSONObject().put("summary",summary()).put("capacity",180)
            .put("samples",new JSONArray(samples)).put("visibilityProof",false).toString(); }
        catch(org.json.JSONException e) { return "{}"; }
    }
}
