package com.catkiss.senlive2dcompanion;

/** Immutable screen-space performance, shared by every already calibrated draw pass.
 * Rotation is isotropic in pixels, about the lower legs, never a model parameter. */
final class CaicaiRootTransform {
    static final CaicaiRootTransform IDENTITY = new CaicaiRootTransform(1,0,0,1,0,0);
    final float a,b,c,d,tx,ty;
    private CaicaiRootTransform(float a,float b,float c,float d,float tx,float ty) {
        this.a=a; this.b=b; this.c=c; this.d=d; this.tx=tx; this.ty=ty;
    }
    static CaicaiRootTransform create(float width,float height,float left,float right,
            float top,float bottom,float shift,float degrees,float pivotHeight) {
        if(width<=0 || height<=0 || right<=left || top<=bottom) return IDENTITY;
        float angle=(float)Math.toRadians(Math.max(-10,Math.min(10,degrees)));
        float cos=(float)Math.cos(angle),sin=(float)Math.sin(angle),aspect=width/height;
        float a=cos,b=sin*aspect,c=-sin/aspect,d=cos;
        float px=(left+right)*.5f, py=top-(top-bottom)*pivotHeight;
        return new CaicaiRootTransform(a,b,c,d,
            px-a*px-c*py+Math.max(-.15f,Math.min(.15f,shift))*(right-left),py-b*px-d*py);
    }
    float[] matrix() { return new float[]{a,b,0,0,c,d,0,0,0,0,1,0,tx,ty,0,1}; }
    void inverse(float x,float y,float[] out) {
        float det=a*d-b*c; x-=tx; y-=ty;
        out[0]=(d*x-c*y)/det; out[1]=(-b*x+a*y)/det;
    }
}
