package com.catkiss.senlive2dcompanion;

/** One rigid transform for every drawable in the screen-right ear pass.
 * Offsets are fractions of its unadjusted width, so stage/form scaling carries
 * the adjustment. Applied after pair constraints, before the common root matrix. */
final class CaicaiRightEarAdjustment {
    static float[] matrix(float[] bounds, float width, float height, float dx, float dy, float degrees) {
        float[] m = {1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1};
        if (bounds == null || bounds.length < 4 || !(width > 0) || !(height > 0)) return m;
        float span = bounds[2] - bounds[0];
        float x = (bounds[0] + bounds[2]) * .5f, y = (bounds[1] + bounds[3]) * .5f;
        if (!(span > 0) || !Float.isFinite(span) || !Float.isFinite(x) || !Float.isFinite(y)) return m;
        dx = bounded(dx, 1); dy = bounded(dy, 1); degrees = bounded(degrees, 45);
        double angle = Math.toRadians(degrees);
        float c = (float)Math.cos(angle), s = (float)Math.sin(angle);
        m[0] = c; m[1] = s; m[4] = -s; m[5] = c;
        m[12] = x-c*x+s*y+dx*span;
        m[13] = y-s*x-c*y+dy*span*width/height;
        CaicaiEarRotation.correct(m,width,height,x,y);
        return m;
    }
    private static float bounded(float value, float limit) {
        return Float.isFinite(value) ? Math.max(-limit,Math.min(limit,value)) : 0;
    }
}
