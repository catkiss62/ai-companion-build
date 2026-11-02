package com.catkiss.senlive2dcompanion;
import org.junit.Test;
import static org.junit.Assert.*;
import com.live2d.sdk.cubism.framework.math.CubismMatrix44;

public class DeepseekLegPivotTest {
    private static DeepseekLegPivot.Bounds b(float l,float r,float t,float bottom) {
        return new DeepseekLegPivot.Bounds(l,r,t,bottom);
    }
    @Test public void legSelectionFollowsOnlyItsPartTreeAndCannotLoop() {
        int[] parents={-1,0,1,0,3,4};boolean[] legs={false,true,false,false,false,false};
        assertTrue(DeepseekLegPivot.belongsToLeg(2,parents,legs));
        assertFalse(DeepseekLegPivot.belongsToLeg(4,parents,legs));
        assertFalse(DeepseekLegPivot.belongsToLeg(-1,parents,legs));
        parents[3]=5;assertFalse(DeepseekLegPivot.belongsToLeg(5,parents,legs));
    }
    @Test public void normalGeometryPreservesExistingPivotAndRootMatrix() {
        DeepseekLegPivot.Bounds whole=b(-1,1,1,-3),legs=b(-.4f,.4f,-1,-3);
        for(float pivot:new float[]{.55f,.7f,.88f,1}) {
            float[] p=DeepseekLegPivot.map(whole,legs,legs,pivot);
            assertArrayEquals(new float[]{0,1-4*pivot,2},p,.00001f);
            assertArrayEquals(CaicaiRootTransform.create(1280,2204,-1,1,1,-3,.055f,7,pivot).matrix(),
                DeepseekLegPivot.matrix(1280,2204,p[0],p[1],p[2],.055f,7),.00001f);
        }
    }
    @Test public void headAnchoredShrinkMovesPivotEvenIfOtherMeshesKeepNormalBounds() {
        float anchor=.8f,ratio=.22f;
        float[] p=DeepseekLegPivot.map(b(-1,1,1,-3),b(-.4f,.4f,-1,-3),
            b(-.4f*ratio,.4f*ratio,anchor+(-1-anchor)*ratio,anchor+(-3-anchor)*ratio),.88f);
        assertEquals(anchor+(-2.52f-anchor)*ratio,p[1],.00001f);
        assertEquals(2*ratio,p[2],.00001f);
        for(float angle:new float[]{-10,10}) {
            float[] old=CaicaiRootTransform.create(1280,2204,-1,1,1,-3,0,angle,.88f).matrix();
            float[] fixed=DeepseekLegPivot.matrix(1280,2204,p[0],p[1],p[2],0,angle);
            assertTrue(Math.abs(old[4]*anchor+old[12])>.9f);
            assertTrue(Math.abs(fixed[4]*anchor+fixed[12])<.23f);
            assertEquals(p[0],fixed[0]*p[0]+fixed[4]*p[1]+fixed[12],.00001f);
            assertEquals(p[1],fixed[1]*p[0]+fixed[5]*p[1]+fixed[13],.00001f);
        }
    }
    @Test public void realLegRatiosAndNeckCorrectionInterpolateWithoutDoubleScaling() {
        float last=-2.52f;
        for(int i=0;i<=100;i++) {
            float ratio=1-i*.008f,dx=i*.001f,dy=i*.002f;
            float[] p=DeepseekLegPivot.map(b(-1,1,1,-3),b(-.4f,.4f,-1,-3),
                b(-.4f*ratio+dx,.4f*ratio+dx,.8f+(-1-.8f)*ratio+dy,.8f+(-3-.8f)*ratio+dy),.88f);
            assertEquals(dx,p[0],.00001f);assertEquals(.8f+(-2.52f-.8f)*ratio+dy,p[1],.00001f);
            assertTrue(p[1]>=last-.00001f);assertTrue(p[1]-last<.03f);last=p[1];
        }
    }
    @Test public void stageZoomCropAndHitInverseUseTheSameMappedPoint() {
        for(float scale:new float[]{.7f,1.7785187f,2.5f}) for(float angle:new float[]{-10,0,10}) {
            float[] m={scale,0,0,0,0,scale*.58f,0,0,0,0,1,0,.003508f,-.492301f,0,1};
            float px=.04f,py=.08f,cx=m[0]*px+m[12],cy=m[5]*py+m[13];
            CubismMatrix44.multiply(m,DeepseekLegPivot.matrix(1280,2204,cx,cy,.44f*scale,0,angle),m);
            float[] crop={1,0,0,0,0,1.2f,0,0,0,0,1,0,0,-.2f,0,1};CubismMatrix44.multiply(m,crop,m);
            assertEquals(cx,m[0]*px+m[4]*py+m[12],.00001f);
            assertEquals(cy*1.2f-.2f,m[1]*px+m[5]*py+m[13],.00001f);
            DeepseekHitTransform hit=new DeepseekHitTransform(m,-.4f,.4f,.8f,-.1f);
            float x=.15f,y=.5f,sx=m[0]*x+m[4]*y+m[12],sy=m[1]*x+m[5]*y+m[13];float[] out=new float[2];
            assertTrue(hit.inverse((sx+1)/2,(1-sy)/2,out));
            assertEquals((x+.4f)/.8f,out[0],.00001f);assertEquals((.8f-y)/.9f,out[1],.00001f);
        }
    }
    @Test public void missingGeometryFailsWithoutNan() {
        DeepseekLegPivot.Bounds valid=b(-1,1,1,-1),empty=new DeepseekLegPivot.Bounds();
        assertNull(DeepseekLegPivot.map(valid,empty,valid,.88f));
        assertNull(DeepseekLegPivot.map(valid,valid,empty,.88f));
        assertNull(DeepseekLegPivot.map(valid,valid,valid,Float.NaN));
    }
}
