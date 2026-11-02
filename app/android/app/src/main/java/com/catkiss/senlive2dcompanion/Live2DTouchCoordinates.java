package com.catkiss.senlive2dcompanion;

/** Pure UI coordinate conversion. Caicai keeps its existing window normalization. */
final class Live2DTouchCoordinates {
    static float[] window(float x,float y,int width,int height) {
        return normalized(x,y,Math.max(1,width),Math.max(1,height));
    }
    static float[] stage(float x,float y,int originX,int originY,int width,int height) {
        if(width<=0 || height<=0) return null;
        return normalized(x-originX,y-originY,width,height);
    }
    private static float[] normalized(float x,float y,int width,int height) {
        if(!Float.isFinite(x) || !Float.isFinite(y)) return null;
        return new float[]{clamp(x*2f/width-1),clamp(1-y*2f/height)};
    }
    private static float clamp(float x) {return Math.max(-1,Math.min(1,x));}
}
