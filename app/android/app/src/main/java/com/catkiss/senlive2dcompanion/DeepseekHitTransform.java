package com.catkiss.senlive2dcompanion;

/** Immutable snapshot of the actual draw transform and visible (including morphed) bounds.
 * UI hit testing never reads mutable Cubism arrays or uses Caicai's cached rectangle. */
final class DeepseekHitTransform {
    static final DeepseekHitTransform INVALID=new DeepseekHitTransform();
    private final float a,b,c,d,tx,ty,left,right,top,bottom,det;
    private DeepseekHitTransform() {a=b=c=d=tx=ty=left=right=top=bottom=det=0;}
    DeepseekHitTransform(float[] m,float left,float right,float top,float bottom) {
        a=m[0];b=m[1];c=m[4];d=m[5];tx=m[12];ty=m[13];
        this.left=left;this.right=right;this.top=top;this.bottom=bottom;det=a*d-b*c;
    }
    boolean inverse(float sx,float sy,float[] result) {
        if(result==null || result.length<2 || !Float.isFinite(sx) || !Float.isFinite(sy)
            || !Float.isFinite(det) || Math.abs(det)<1e-8f || right<=left || top<=bottom) return false;
        float x=sx*2-1-tx,y=1-sy*2-ty;
        float mx=(d*x-c*y)/det,my=(-b*x+a*y)/det;
        result[0]=(mx-left)/(right-left);result[1]=(top-my)/(top-bottom);
        return Float.isFinite(result[0])&&Float.isFinite(result[1]);
    }
}
