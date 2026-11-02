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
    /** Horizontal containment after the complete draw transform. The morph changes meshes,
     * not stage scale: limiting parameter/root inputs cannot bound this final screen rectangle.
     * No persistent stage setting is changed. Oversized user zooms keep their intentional crop. */
    static float smallFormShift(float[] m,float left,float right,float top,float bottom,float weight) {
        if(m==null || m.length!=16 || right<=left || top<=bottom || !Float.isFinite(weight) || weight<=0) return 0;
        float min=Float.POSITIVE_INFINITY,max=Float.NEGATIVE_INFINITY;
        for(int corner=0;corner<4;corner++) {
            float x=(corner&1)==0?left:right,y=(corner&2)==0?top:bottom;
            float sx=m[0]*x+m[4]*y+m[12];
            if(!Float.isFinite(sx)) return 0;
            min=Math.min(min,sx);max=Math.max(max,sx);
        }
        float half=(max-min)*.5f,lo=-.94f+half,hi=.94f-half;
        if(hi<=lo) return 0;
        float center=(min+max)*.5f,band=Math.min(.12f,(hi-lo)*.2f),wanted=center;
        // Identity in the middle; continuously soften near either edge, never cross it.
        if(center<lo+band) wanted=lo+band*(float)Math.exp((center-lo-band)/band);
        else if(center>hi-band) wanted=hi-band*(float)Math.exp((hi-band-center)/band);
        float w=Math.max(0,Math.min(1,weight));w=w*w*(3-2*w);
        return (wanted-center)*w;
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
