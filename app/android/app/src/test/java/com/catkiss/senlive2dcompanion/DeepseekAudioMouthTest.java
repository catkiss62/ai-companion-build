package com.catkiss.senlive2dcompanion;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.*;
import org.junit.Test;
import static org.junit.Assert.*;

public class DeepseekAudioMouthTest {
    private final DeepseekAudioMouth analyzer=new DeepseekAudioMouth();
    private static byte[] signal(int rate,int channels,int bits,double first,double second,double gain,int offset) {
        int frames=rate/25,bytes=bits/8;
        ByteBuffer b=ByteBuffer.allocate(offset+frames*channels*bytes+7).order(ByteOrder.LITTLE_ENDIAN);
        b.position(offset);
        for(int i=0;i<frames;i++) for(int c=0;c<channels;c++) {
            // Distinct right-channel noise makes accidental byte/channel offsets visible.
            double v=c==0?gain*(Math.sin(2*Math.PI*first*i/rate)+.65*Math.sin(2*Math.PI*second*i/rate)):.7;
            if(bits==16) b.putShort((short)(v*32767));else b.putFloat((float)v);
        }
        return b.array();
    }
    private DeepseekAudioMouth.Shape shape(double first,double second) {
        return analyzer.analyze(signal(24000,1,16,first,second,.2,0),0,960,24000,1,16,1);
    }
    @Test public void differentResonancesChangeShapeAtEqualLoudness() {
        DeepseekAudioMouth.Shape narrow=shape(350,900),wide=shape(350,2500),open=shape(850,1400);
        assertTrue(narrow.width<-.25f);assertTrue(wide.width>.25f);
        assertTrue(open.opening>narrow.opening+.15f);
        assertTrue(open.opening<=1.12f);
    }
    @Test public void pcmFormatOffsetAndFirstChannelAgreeWithoutMutatingAudio() {
        byte[] mono=signal(24000,1,16,350,2500,.2,0);
        byte[] stereo=signal(24000,2,32,350,2500,.2,13),before=stereo.clone();
        DeepseekAudioMouth.Shape a=analyzer.analyze(mono,0,960,24000,1,16,1);
        DeepseekAudioMouth.Shape b=analyzer.analyze(stereo,13,960,24000,2,32,3);
        assertEquals(a.width,b.width,.03f);assertEquals(a.opening,b.opening,.03f);
        assertArrayEquals(before,stereo);
    }
    @Test public void hintsSurviveCommonSampleRatesAndVolumeChanges() {
        for(int rate:new int[]{8000,16000,22050,24000,44100,48000,96000}) {
            DeepseekAudioMouth.Shape a=analyzer.analyze(signal(rate,1,16,350,2500,.2,0),0,rate/25,rate,1,16,1);
            DeepseekAudioMouth.Shape b=analyzer.analyze(signal(rate,1,16,350,2500,.05,0),0,rate/25,rate,1,16,1);
            assertTrue("rate "+rate,a.width>.2f);
            assertEquals(a.width,b.width,.04f);assertEquals(a.opening,b.opening,.04f);
        }
    }
    @Test public void silenceDcNoiseHighSibilanceAndShortChunksUseNeutralHints() {
        assertSame(DeepseekAudioMouth.NEUTRAL,analyzer.analyze(new byte[1920],0,960,24000,1,16,1));
        ByteBuffer dc=ByteBuffer.allocate(3840).order(ByteOrder.LITTLE_ENDIAN);
        for(int i=0;i<960;i++) dc.putFloat(.25f);
        assertSame(DeepseekAudioMouth.NEUTRAL,analyzer.analyze(dc.array(),0,960,24000,1,32,3));
        byte[] noise=new byte[1920];new Random(416).nextBytes(noise);
        assertSame(DeepseekAudioMouth.NEUTRAL,analyzer.analyze(noise,0,960,24000,1,16,1));
        assertSame(DeepseekAudioMouth.NEUTRAL,shape(4200,4700));
        assertSame(DeepseekAudioMouth.NEUTRAL,analyzer.analyze(noise,0,200,24000,1,16,1));
    }
    @Test public void malformedAndNonFinitePcmFallBackSafely() {
        byte[] bytes=new byte[3840];
        ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN).putFloat(Float.NaN);
        assertSame(DeepseekAudioMouth.NEUTRAL,analyzer.analyze(bytes,0,960,24000,1,32,3));
        assertSame(DeepseekAudioMouth.NEUTRAL,analyzer.analyze(bytes,-1,960,24000,1,16,1));
        assertSame(DeepseekAudioMouth.NEUTRAL,analyzer.analyze(bytes,0,960,24000,0,16,1));
        assertSame(DeepseekAudioMouth.NEUTRAL,analyzer.analyze(bytes,0,Integer.MAX_VALUE,24000,2,16,1));
        assertSame(DeepseekAudioMouth.NEUTRAL,analyzer.analyze(bytes,0,960,24000,1,8,1));
    }

    private static final class Pose implements DeepseekParameterPlan.Target {
        final Map<String,Float> values=new HashMap<>();
        public boolean accepts(String id) {return true;}
        public float current(String id) {return values.getOrDefault(id,0f);}
        public void write(String id,float value) {values.put(id,value);}
    }
    @Test public void shapesKeepSmileStyleTongueAndCenteredMouthThroughPhysics() {
        DeepseekSpeechMouth m=new DeepseekSpeechMouth();Pose p=new Pose();
        p.write("ParamMouthForm",1);p.write("MouthPressLipOpen",-1);p.write("CheeckPuff",.3f);
        p.write("MouthFunnel",.4f);p.write("Mouthpucker",.2f);p.write("MouthPuckerWiden",.2f);
        m.signal(.45f,1.12f,1_000_000_000L);m.advance(.1f,true,1_000_000_001L);
        m.capture(p);m.applyFrame(.4f,p,-.12f);float width=p.current("MouthPuckerWiden"),open=p.current("ParamMouthOpenY");
        assertTrue(width>.5f);assertTrue(open>.48f);assertEquals(-.12f,p.current("MouthX"),0);
        p.write("ParamMouthForm",0);p.write("MouthPuckerWiden",-.9f);
        m.restore(p);m.applyFrame(.4f,p,-.12f);
        assertEquals(width,p.current("MouthPuckerWiden"),.00001f);
        assertEquals(open,p.current("ParamMouthOpenY"),.00001f);
        assertEquals(1,p.current("ParamMouthForm"),0);assertEquals(-1,p.current("MouthPressLipOpen"),0);
        assertEquals(.3f,p.current("CheeckPuff"),0);assertEquals(.4f,p.current("MouthFunnel"),0);
        assertEquals(.2f,p.current("Mouthpucker"),0);
        p.write("TongueOut",1);p.write("MouthPuckerWiden",.2f);m.applyFrame(.4f,p,0);
        assertEquals(1,p.current("TongueOut"),0);assertEquals(.2f,p.current("MouthPuckerWiden"),0);
        assertEquals(.48f,p.current("ParamMouthOpenY"),.00001f);
    }
    @Test public void stopPauseExpiryAndInvalidSignalsCannotLeaveAStaleShape() {
        DeepseekSpeechMouth m=new DeepseekSpeechMouth();Pose p=new Pose();
        m.signal(.45f,.78f,1_000_000_000L);m.advance(.1f,true,1_000_000_001L);
        m.advance(.016f,false,1_000_000_002L);m.applyFrame(.4f,p,0);
        assertEquals(0,p.current("MouthPuckerWiden"),0);assertEquals(.48f,p.current("ParamMouthOpenY"),.00001f);
        m.signal(.45f,.78f,2_000_000_000L);m.advance(.1f,true,2_000_000_001L);
        for(int i=0;i<10;i++) m.advance(.1f,true,3_000_000_000L+i);
        p.write("MouthPuckerWiden",0);m.applyFrame(.4f,p,0);
        assertEquals(0,p.current("MouthPuckerWiden"),.0001f);assertEquals(.48f,p.current("ParamMouthOpenY"),.0001f);
        m.signal(Float.NaN,Float.POSITIVE_INFINITY,4_000_000_000L);m.advance(.1f,true,4_000_000_001L);
        p.write("MouthPuckerWiden",0);m.applyFrame(.4f,p,0);
        assertEquals(0,p.current("MouthPuckerWiden"),.0001f);
        m.applyFrame(0,p,0);assertEquals(0,p.current("ParamMouthOpenY"),0);
    }
    @Test public void missingAnalysisUsesTheOriginalOpeningAndBoundsAlwaysHold() {
        DeepseekSpeechMouth m=new DeepseekSpeechMouth();Pose p=new Pose();
        m.advance(.016f,true,1);m.applyFrame(.4f,p,0);
        assertEquals(.48f,p.current("ParamMouthOpenY"),.00001f);
        m.signal(100,100,1);m.advance(.1f,true,2);p.write("MouthPuckerWiden",.9f);m.applyFrame(1,p,0);
        assertEquals(1,p.current("MouthPuckerWiden"),0);assertEquals(1,p.current("ParamMouthOpenY"),0);
    }
}
