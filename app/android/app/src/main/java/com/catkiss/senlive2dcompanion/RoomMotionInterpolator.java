package com.catkiss.senlive2dcompanion;

/** Same 35ms display-frame response as Flutter; no dependence on sensor cadence. */
final class RoomMotionInterpolator {
    private float targetX, targetY;
    private long lastFrame;
    float x, y;

    void target(float newX, float newY) {
        targetX=Float.isFinite(newX) ? Math.max(-1f,Math.min(1f,newX)) : 0f;
        targetY=Float.isFinite(newY) ? Math.max(-1f,Math.min(1f,newY)) : 0f;
    }
    void reset() { targetX=targetY=x=y=0f; lastFrame=0; }
    void frame(long now) {
        if(now<=lastFrame) return;
        if(lastFrame==0) { lastFrame=now; return; }
        double dt=Math.min(.05,(now-lastFrame)/1e9);
        lastFrame=now;
        float alpha=(float)(1-Math.exp(-dt/.035));
        x+=(targetX-x)*alpha; y+=(targetY-y)*alpha;
        float dx=targetX-x,dy=targetY-y;
        if(dx*dx+dy*dy<1e-8f) {
            x=targetX; y=targetY;
        }
    }
}
