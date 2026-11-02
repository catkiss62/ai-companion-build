package com.catkiss.senlive2dcompanion;

/** Map the normal shin calibration through the imported rig's leg deformation.
 * Controls/masks in the whole-model rectangle need not shrink with Clothes2. */
final class DeepseekLegPivot {
    static final class Bounds {
        float left,right,top,bottom;
        Bounds() { clear(); }
        Bounds(float l,float r,float t,float b) {left=l;right=r;top=t;bottom=b;}
        void clear() {left=bottom=Float.POSITIVE_INFINITY;right=top=Float.NEGATIVE_INFINITY;}
        void include(float x,float y) {
            if(!Float.isFinite(x) || !Float.isFinite(y)) return;
            left=Math.min(left,x);right=Math.max(right,x);bottom=Math.min(bottom,y);top=Math.max(top,y);
        }
        boolean valid() {return Float.isFinite(left) && Float.isFinite(right) && Float.isFinite(top)
            && Float.isFinite(bottom) && width()>1e-5f && height()>1e-5f;}
        float width() {return right-left;}
        float height() {return top-bottom;}
    }
    static boolean belongsToLeg(int part,int[] parents,boolean[] legs) {
        for(int n=0;part>=0 && part<parents.length && part<legs.length && n<parents.length;n++) {
            if(legs[part]) return true;
            part=parents[part];
        }
        return false;
    }
    /** Same pose before/after morph. Live legs already include the neck correction.
     * Result is model-space pivot x/y and the corresponding horizontal travel span. */
    static float[] map(Bounds normal,Bounds normalLegs,Bounds liveLegs,float pivot) {
        if(!normal.valid() || !normalLegs.valid() || !liveLegs.valid() || !Float.isFinite(pivot)) return null;
        float x=(normal.left+normal.right)*.5f,y=normal.top-normal.height()*pivot;
        float px=liveLegs.left+(x-normalLegs.left)/normalLegs.width()*liveLegs.width();
        float py=liveLegs.top-(normalLegs.top-y)/normalLegs.height()*liveLegs.height();
        float span=normal.width()/normalLegs.width()*liveLegs.width();
        return Float.isFinite(px) && Float.isFinite(py) && Float.isFinite(span)?new float[]{px,py,span}:null;
    }
    /** Pixel-isotropic root rotation about the explicitly mapped point. */
    static float[] matrix(float width,float height,float px,float py,float span,float shift,float degrees) {
        if(width<=0 || height<=0 || !Float.isFinite(px) || !Float.isFinite(py) || !Float.isFinite(span))
            return CaicaiRootTransform.IDENTITY.matrix();
        float angle=(float)Math.toRadians(Math.max(-10,Math.min(10,degrees)));
        float cos=(float)Math.cos(angle),sin=(float)Math.sin(angle),aspect=width/height;
        float a=cos,b=sin*aspect,c=-sin/aspect,d=cos;
        return new float[]{a,b,0,0,c,d,0,0,0,0,1,0,
            px-a*px-c*py+Math.max(-.15f,Math.min(.15f,shift))*span,py-b*px-d*py,0,1};
    }
}
