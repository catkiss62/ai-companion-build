package com.catkiss.senlive2dcompanion;
import org.junit.Test;
import static org.junit.Assert.*;
import com.live2d.sdk.cubism.framework.math.CubismMatrix44;
public class CaicaiRootTransformTest {
    @Test public void lowerLegPivotStaysFixedAndPixelsRemainIsotropic() {
        for(float aspect:new float[]{.45f,1f,2f}) {
            CaicaiRootTransform t=CaicaiRootTransform.create(1000*aspect,1000,-.6f,.8f,.9f,-.9f,0,7,.88f);
            float px=.1f,py=.9f-1.8f*.88f;
            assertEquals(px,t.a*px+t.c*py+t.tx,.00001f);
            assertEquals(py,t.b*px+t.d*py+t.ty,.00001f);
            float dx=.2f,dy=.13f;
            double before=Math.hypot(dx*aspect,dy),after=Math.hypot((t.a*dx+t.c*dy)*aspect,t.b*dx+t.d*dy);
            assertEquals(before,after,.00001);
        }
    }
    @Test public void calibratedPassesShareOneFinalTransformAndHitInverse() {
        CaicaiRootTransform t=CaicaiRootTransform.create(900,1600,-.6f,.8f,.9f,-.9f,.10f,-7,.88f);
        for(float scale:new float[]{.5f,1f,2f}) {
            CubismMatrix44 m=CubismMatrix44.create(); m.scale(scale,scale); m.translateRelative(.1f,-.2f);
            float[] before=m.getArray().clone(),after=new float[16];
            CubismMatrix44.multiply(before,t.matrix(),after);
            float x=.2f,y=.5f,ox=before[0]*x+before[4]*y+before[12],oy=before[1]*x+before[5]*y+before[13];
            float nx=after[0]*x+after[4]*y+after[12],ny=after[1]*x+after[5]*y+after[13];
            assertEquals(t.a*ox+t.c*oy+t.tx,nx,.00001f);
            assertEquals(t.b*ox+t.d*oy+t.ty,ny,.00001f);
            float[] out=new float[2]; t.inverse(nx,ny,out);
            assertEquals(ox,out[0],.00001f); assertEquals(oy,out[1],.00001f);
        }
    }
}
