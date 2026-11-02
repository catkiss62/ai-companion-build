package com.catkiss.senlive2dcompanion;

/** Read-only lower-leg reference, separating root rotation from root travel.
 * The lower edge of visible leg meshes is a reference, not a claimed sole contact. */
final class DeepseekFootProbe {
    private boolean valid;
    private float baseX,baseY,tiltX,tiltY,drawX,drawY,pivotX,pivotY;
    void capture(float[] base,float[] root,float[] crop,DeepseekLegPivot.Bounds legs,
            float px,float py,float shiftX) {
        valid=legs.valid();if(!valid) return;
        float x=(legs.left+legs.right)*.5f,y=legs.bottom;
        float bx=x(base,x,y),by=y(base,x,y);
        float rx=x(root,bx,by),ry=y(root,bx,by);
        baseX=x(crop,bx,by);baseY=y(crop,bx,by);
        tiltX=x(crop,rx-shiftX,ry);tiltY=y(crop,rx-shiftX,ry);
        drawX=x(crop,rx,ry);drawY=y(crop,rx,ry);
        float ax=x(base,px,py),ay=y(base,px,py);
        pivotX=x(crop,ax,ay);pivotY=y(crop,ax,ay);
        valid=Float.isFinite(baseX) && Float.isFinite(baseY) && Float.isFinite(drawX) && Float.isFinite(drawY);
    }
    String trace() {return "lowerLegRef="+(valid?"visible_leg_bounds_lower":"unavailable")+
        " legBeforeRoot="+baseX+","+baseY+" legAfterTilt="+tiltX+","+tiltY+
        " legDraw="+drawX+","+drawY+" tiltPivotClip="+pivotX+","+pivotY;}
    static float x(float[] m,float x,float y) {return m[0]*x+m[4]*y+m[12];}
    static float y(float[] m,float x,float y) {return m[1]*x+m[5]*y+m[13];}
}
