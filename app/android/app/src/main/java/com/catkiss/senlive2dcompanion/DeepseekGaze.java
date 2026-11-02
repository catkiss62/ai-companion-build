package com.catkiss.senlive2dcompanion;

/** GL-owned eye-white reference in the final rendered viewport. No Core writes. */
final class DeepseekGaze {
    private float eyeX=.5f,eyeY=.5f,aspect=1,stageX,stageY,aimX,aimY;
    private boolean calibrated;
    void capture(float[] m,DeepseekLegPivot.Bounds whites,float width,float height) {
        if(width<=0 || height<=0) return;
        aspect=height/width;
        if(!whites.valid()) return; // Blink/special eyes retain the last visible reference.
        float x=(whites.left+whites.right)*.5f,y=(whites.top+whites.bottom)*.5f;
        float nx=(m[0]*x+m[4]*y+m[12]+1)*.5f;
        float ny=(1-(m[1]*x+m[5]*y+m[13]))*.5f;
        if(Float.isFinite(nx) && Float.isFinite(ny)) {eyeX=nx;eyeY=ny;calibrated=true;}
    }
    float[] direction(float x,float y) {
        if(!Float.isFinite(x) || !Float.isFinite(y)) return null;
        stageX=clamp(x);stageY=clamp(y);
        // One pixel scale for both axes: a tall window must not dilute down-look.
        aimX=calibrated?clamp((stageX+1)-2*eyeX):stageX;
        aimY=calibrated?clamp((2*eyeY-(1-stageY))*aspect):stageY;
        return new float[]{aimX,aimY};
    }
    void clear() {calibrated=false;stageX=stageY=aimX=aimY=0;}
    String trace() {return "gazeOrigin="+eyeX+","+eyeY+" gazeBound="+calibrated+
        " pointer="+stageX+","+stageY+" gazeAim="+aimX+","+aimY;}
    private static float clamp(float x) {return Math.max(-1,Math.min(1,x));}
}
