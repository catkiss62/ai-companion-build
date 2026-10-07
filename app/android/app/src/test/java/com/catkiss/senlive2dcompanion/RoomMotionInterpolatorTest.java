package com.catkiss.senlive2dcompanion;

import org.junit.Test;
import static org.junit.Assert.*;

public class RoomMotionInterpolatorTest {
    @Test public void displayFramesContinueBetweenSensorEventsAndSettle() {
        RoomMotionInterpolator motion=new RoomMotionInterpolator();
        motion.frame(1);motion.target(1,-1);
        float previous=0;
        for(int frame=1;frame<=8;frame++) {
            motion.frame(1+frame*16_666_667L);
            assertTrue(motion.x>previous && motion.x<1);
            assertEquals(-motion.x,motion.y,1e-6f);
            previous=motion.x;
        }
        for(int frame=9;frame<=60;frame++) motion.frame(1+frame*16_666_667L);
        assertEquals(1,motion.x,0);assertEquals(-1,motion.y,0);
        motion.reset();motion.frame(2_000_000_000);
        assertEquals(0,motion.x,0);assertEquals(0,motion.y,0);
    }
    @Test public void equalElapsedTimeMatchesAcrossRefreshRates() {
        assertEquals(response(30),response(60),1e-5f);
        assertEquals(response(60),response(120),1e-5f);
    }
    private float response(int fps) {
        RoomMotionInterpolator motion=new RoomMotionInterpolator();motion.frame(1);motion.target(.8f,-.3f);
        for(int frame=1;frame<=fps/10;frame++) motion.frame(1+Math.round(frame*1e9/fps));
        return motion.x;
    }
    @Test public void invalidInputAndClockDoNotCreateInvalidPose() {
        RoomMotionInterpolator motion=new RoomMotionInterpolator();motion.frame(1);motion.target(5,-5);
        motion.frame(16_666_668);assertTrue(motion.x>0 && motion.x<=1);
        float previous=motion.x;motion.frame(2);assertEquals(previous,motion.x,0);
        motion.target(Float.NaN,Float.POSITIVE_INFINITY);motion.frame(33_333_335);
        assertTrue(Float.isFinite(motion.x) && Float.isFinite(motion.y));
        motion.reset();assertEquals(0,motion.x,0);assertEquals(0,motion.y,0);
    }
}
