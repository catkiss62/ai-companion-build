package com.catkiss.senlive2dcompanion;

import java.util.*;
import org.junit.Test;
import static org.junit.Assert.*;

public class DeepseekViewerFocusTest {
    static final class Pose implements DeepseekParameterPlan.Target {
        final Map<String,Float> values=new HashMap<>();
        public boolean accepts(String id) {return true;}
        public float current(String id) {return values.getOrDefault(id,0f);}
        public void write(String id,float value) {values.put(id,value);}
    }
    @Test public void focusCompensatesFinalHeadAndNeverWritesHeadBodyOrFace() {
        Pose p=new Pose();DeepseekViewerFocus focus=new DeepseekViewerFocus();
        for(int i=0;i<60;i++) {
            p.write("AngleX",25);p.write("AngleY",-24);p.write("AngleZ",18);
            p.write("ParamEyeBallX",.7f);p.write("ParamEyeBallY",-.6f);
            p.write("ParamEyeLOpen",.2f);p.write("PositionZ",23);
            focus.apply(.05f,p,true,false);
        }
        assertEquals(-25f/30*.85f,p.current("ParamEyeBallX"),.001f);
        assertEquals(.56f,p.current("ParamEyeBallY"),.001f);
        assertTrue(Math.abs(p.current("ParamEyeBallX"))>25f/30*.65f);
        assertEquals(25,p.current("AngleX"),0);assertEquals(-24,p.current("AngleY"),0);
        assertEquals(18,p.current("AngleZ"),0);assertEquals(23,p.current("PositionZ"),0);
        assertEquals(.2f,p.current("ParamEyeLOpen"),0);
    }
    @Test public void strongerCompensationIsBoundedAndDoesNotChangeHeadAtExtremeAngles() {
        for(float sign:new float[]{-1,1}) {
            Pose p=new Pose();DeepseekViewerFocus focus=new DeepseekViewerFocus();
            for(int i=0;i<60;i++) {
                p.write("AngleX",sign*45);p.write("AngleY",sign*45);
                focus.apply(.05f,p,true,false);
            }
            assertEquals(-sign*.85f,p.current("ParamEyeBallX"),.001f);
            assertEquals(-sign*.70f,p.current("ParamEyeBallY"),.001f);
            assertEquals(sign*45,p.current("AngleX"),0);assertEquals(sign*45,p.current("AngleY"),0);
        }
    }
    @Test public void manualAndPatOwnershipBypassFocusAndEndingReturnsToLiveIdle() {
        Pose p=new Pose();DeepseekViewerFocus focus=new DeepseekViewerFocus();
        for(int i=0;i<30;i++) focus.apply(.1f,p,true,false);
        p.write("ParamEyeBallX",.8f);focus.apply(.1f,p,true,true);
        assertEquals(.8f,p.current("ParamEyeBallX"),0);assertEquals(0,focus.weight(),0);
        for(int i=0;i<30;i++) focus.apply(.1f,p,true,false);
        for(int i=0;i<40;i++) {p.write("ParamEyeBallX",.3f);focus.apply(.1f,p,false,false);}
        assertEquals(.3f,p.current("ParamEyeBallX"),.001f);
    }
    @Test public void fixedMouthFaceIsVisibleAtOpeningButDisabledForRealSpeech() {
        Pose p=new Pose();DeepseekExpressions e=new DeepseekExpressions();
        e.trigger("嫌弃眼","","");e.apply(.3f,false,p);e.overlay(p,false);
        assertTrue(p.current("key6")>.8f);assertFalse(e.reservesEyes(false));
        e.overlay(p,true);assertEquals(0,p.current("key6"),0);assertFalse(e.reservesEyes(true));
        e.trigger("爱心眼","","");e.apply(.3f,false,p);e.overlay(p,true);
        assertTrue(p.current("key4")>.8f);assertFalse(e.reservesEyes(true));
    }
}
