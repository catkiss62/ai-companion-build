package com.catkiss.senlive2dcompanion;
import org.junit.Test;
import static org.junit.Assert.*;
import com.live2d.sdk.cubism.framework.math.CubismMatrix44;

public class DeepseekLegPivotTest {
    private static DeepseekLegPivot.Bounds b(float l,float r,float t,float bottom) {
        return new DeepseekLegPivot.Bounds(l,r,t,bottom);
    }
    @Test public void smallAxisUsesCurrentLowerLegsAndKeepsTheSavedControl() {
        DeepseekLegPivot.Bounds legs=b(-.08f,.08f,.44f,.04f);
        float[] mapped=DeepseekLegPivot.map(b(-1,1,1,-3),b(-.4f,.4f,-1,-3),legs,.88f);
        float[] before=mapped.clone();
        float[] lower=DeepseekLegPivot.withSmallFormAnchor(mapped,legs,.88f,.55f);
        assertEquals(.064f,lower[1],.00001f);
        assertEquals(mapped[0],lower[0],0);assertEquals(mapped[2],lower[2],0);
        assertArrayEquals(before,mapped,0);
        assertArrayEquals(mapped,DeepseekLegPivot.withSmallFormAnchor(mapped,legs,.88f,0),0);
        assertEquals(legs.bottom,DeepseekLegPivot.withSmallFormAnchor(mapped,legs,1,.55f)[1],.00001f);
        assertTrue(DeepseekLegPivot.withSmallFormAnchor(mapped,legs,.7f,.55f)[1]>lower[1]);
        assertArrayEquals(mapped,DeepseekLegPivot.withSmallFormAnchor(mapped,new DeepseekLegPivot.Bounds(),.88f,.55f),0);
        assertArrayEquals(mapped,DeepseekLegPivot.withSmallFormAnchor(mapped,legs,.88f,Float.NaN),0);
        assertNull(DeepseekLegPivot.withSmallFormAnchor(null,legs,.88f,.55f));
    }
    @Test public void enteringAndLeavingSmallFormRetraceAContinuousAxisForEverySavedSize() {
        for(float target:new float[]{.2f,.55f,.8f,1}) {
            float previous=Float.NaN;
            float[] forward=new float[101];
            for(int i=0;i<=100;i++) {
                float form=target*i/100,ratio=1-.8f*i/100;
                DeepseekLegPivot.Bounds live=b(-.4f*ratio,.4f*ratio,.8f+(-1-.8f)*ratio,.8f+(-3-.8f)*ratio);
                float[] mapped=DeepseekLegPivot.map(b(-1,1,1,-3),b(-.4f,.4f,-1,-3),live,.88f);
                float y=DeepseekLegPivot.withSmallFormAnchor(mapped,live,.88f,form)[1];
                assertTrue(Float.isFinite(y));
                if(i>0) assertTrue(Math.abs(y-previous)<.05f);
                forward[i]=previous=y;
            }
            for(int i=100;i>=0;i--) {
                float form=target*i/100,ratio=1-.8f*i/100;
                DeepseekLegPivot.Bounds live=b(-.4f*ratio,.4f*ratio,.8f+(-1-.8f)*ratio,.8f+(-3-.8f)*ratio);
                float[] mapped=DeepseekLegPivot.map(b(-1,1,1,-3),b(-.4f,.4f,-1,-3),live,.88f);
                assertEquals(forward[i],DeepseekLegPivot.withSmallFormAnchor(mapped,live,.88f,form)[1],.000001f);
            }
        }
    }
    @Test public void lowerAxisReducesFootRotationWhileWholeModelTravelAndHitInverseStillWork() {
        DeepseekLegPivot.Bounds live=b(-.08f,.08f,.44f,.04f);
        float[] mapped=DeepseekLegPivot.map(b(-1,1,1,-3),b(-.4f,.4f,-1,-3),live,.88f);
        float[] lower=DeepseekLegPivot.withSmallFormAnchor(mapped,live,.88f,.55f);
        for(float angle:new float[]{-10,10}) {
            float[] old=DeepseekLegPivot.matrix(1280,2204,0,mapped[1],mapped[2],0,angle);
            float[] fixed=DeepseekLegPivot.matrix(1280,2204,0,lower[1],lower[2],0,angle);
            float oldFoot=old[4]*live.bottom+old[12],newFoot=fixed[4]*live.bottom+fixed[12];
            assertTrue(Math.abs(newFoot)<Math.abs(oldFoot)*.3f);
            assertEquals(lower[1],fixed[5]*lower[1]+fixed[13],.00001f);
            float[] travel=DeepseekLegPivot.matrix(1280,2204,0,lower[1],lower[2],.1f,angle);
            assertEquals(.1f*lower[2],travel[12]-fixed[12],.000001f);
            DeepseekHitTransform hit=new DeepseekHitTransform(travel,-.08f,.08f,.44f,.04f);
            float x=.02f,y=.3f,sx=travel[0]*x+travel[4]*y+travel[12],sy=travel[1]*x+travel[5]*y+travel[13];
            float[] inverse=new float[2];assertTrue(hit.inverse((sx+1)/2,(1-sy)/2,inverse));
            assertEquals((x+.08f)/.16f,inverse[0],.00001f);assertEquals((.44f-y)/.4f,inverse[1],.00001f);
        }
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
    @Test public void repeatedCorrectionLeavesRetainedCoreVerticesUntouched() {
        // A Core buffer is allowed to remain unchanged while the rig is idle.
        float[] retained={-.08f,.44f,.08f,.04f};float[] original=retained.clone();
        float previous=Float.NaN;
        for(int frame=0;frame<3600;frame++) {
            float morph=frame<1200?.55f:frame<2400?0:.55f;
            float dx=morph>.001f?.07f:0,dy=morph>.001f?.23f:0;
            float[] m={1.7785187f,0,0,0,0,1.032f,0,0,0,0,1,0,.003508f,-.492301f,0,1};
            float[] raw=DeepseekLegPivot.map(b(-1,1,1,-3),b(-.4f,.4f,-1,-3),
                b(retained[0],retained[2],retained[1],retained[3]),.88f);
            DeepseekLegPivot.translateModel(m,dx,dy);
            float px=m[0]*raw[0]+m[4]*raw[1]+m[12],py=m[1]*raw[0]+m[5]*raw[1]+m[13];
            float angle=frame%600<300?7:0;
            CubismMatrix44.multiply(m,DeepseekLegPivot.matrix(1280,2204,px,py,m[0]*raw[2],0,angle),m);
            assertArrayEquals(original,retained,0);
            assertEquals(py,m[1]*raw[0]+m[5]*raw[1]+m[13],.00001f);
            if(frame>0 && frame!=1200 && frame!=2400) assertEquals(previous,py,.00001f);
            previous=py;
        }
    }
    @Test public void matrixShiftMatchesOneTimeGeometryShiftWithRotationAndHitInverse() {
        float[] base={1.4f,.2f,0,0,-.1f,.8f,0,0,0,0,1,0,.02f,-.4f,0,1};
        float dx=.15f,dy=.6f,x=.12f,y=.3f;
        float expectedX=base[0]*(x+dx)+base[4]*(y+dy)+base[12];
        float expectedY=base[1]*(x+dx)+base[5]*(y+dy)+base[13];
        DeepseekLegPivot.translateModel(base,dx,dy);
        assertEquals(expectedX,base[0]*x+base[4]*y+base[12],.00001f);
        assertEquals(expectedY,base[1]*x+base[5]*y+base[13],.00001f);
        DeepseekHitTransform hit=new DeepseekHitTransform(base,-.4f,.4f,.8f,-.1f);float[] out=new float[2];
        assertTrue(hit.inverse((expectedX+1)/2,(1-expectedY)/2,out));
        assertEquals((x+.4f)/.8f,out[0],.00001f);assertEquals((.8f-y)/.9f,out[1],.00001f);
        float[] before=base.clone();DeepseekLegPivot.translateModel(base,Float.NaN,1);
        assertArrayEquals(before,base,0);
    }
}
