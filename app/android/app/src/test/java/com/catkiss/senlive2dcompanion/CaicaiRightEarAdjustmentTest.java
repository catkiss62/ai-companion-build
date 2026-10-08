package com.catkiss.senlive2dcompanion;
import org.junit.Test;
import static org.junit.Assert.*;
public class CaicaiRightEarAdjustmentTest {
    @Test public void allPointsMoveRigidlyAndOffsetsScaleWithEarWidth() {
        for(float aspect:new float[]{.45f,1f,1.8f}) for(float size:new float[]{.3f,1f,2f}) {
            float[] bounds={-.2f*size,-.1f*size,.3f*size,.2f*size};
            float[] m=CaicaiRightEarAdjustment.matrix(bounds,1000*aspect,1000,.2f,-.3f,23);
            float x=(bounds[0]+bounds[2])/2,y=(bounds[1]+bounds[3])/2,span=bounds[2]-bounds[0];
            assertEquals(x+.2f*span,m[0]*x+m[4]*y+m[12],.000001f);
            assertEquals(y-.3f*span*aspect,m[1]*x+m[5]*y+m[13],.000001f);
            for(float[] v:new float[][]{{.12f,0},{0,.08f},{.15f,.07f}})
                assertEquals(Math.hypot(v[0]*aspect,v[1]),Math.hypot((m[0]*v[0]+m[4]*v[1])*aspect,m[1]*v[0]+m[5]*v[1]),.000001);
            float[] zero=CaicaiRightEarAdjustment.matrix(bounds,1000*aspect,1000,0,0,0);
            assertArrayEquals(new float[]{1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1},zero,0);
        }
    }
}
