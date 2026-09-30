package com.catkiss.senlive2dcompanion;

/** Limits only the custom lower-leg-pivot draw transform, never model Body XYZ. */
final class CaicaiRootTiltSmoother {
    // Idle's sharpest phrase is bounded by 6.5 * 1.2 * PI / 1.25 = 19.6 deg/s.
    static final float DEFAULT_MAX_DEGREES_PER_SECOND = 25f;
    private float displayed, gain = 1f, speed = 1f;

    void tune(float gain, float speed) {
        this.gain = Float.isFinite(gain) ? Math.max(.5f, Math.min(1.5f, gain)) : 1f;
        this.speed = Float.isFinite(speed) ? Math.max(.5f, Math.min(1.6f, speed)) : 1f;
    }
    float value() { return displayed; }
    void reset() { displayed = 0f; }
    float update(float target, float deltaSeconds) {
        if (!Float.isFinite(target) || !Float.isFinite(deltaSeconds) || deltaSeconds <= 0f) return displayed;
        target = Math.max(-10f, Math.min(10f, target));
        // A paused renderer must not consume the whole absence as one jump.
        float step = DEFAULT_MAX_DEGREES_PER_SECOND * gain * speed * Math.min(.05f, deltaSeconds);
        displayed += Math.max(-step, Math.min(step, target - displayed));
        return displayed;
    }
}
