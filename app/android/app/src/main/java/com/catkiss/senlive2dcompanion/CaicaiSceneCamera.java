package com.catkiss.senlive2dcompanion;

/** A full, top-anchored scene viewed through a smaller IME-clipped surface. */
final class CaicaiSceneCamera {
    private float ratio;
    void setScene(float width, float height) {
        if (Float.isFinite(width) && Float.isFinite(height) && width > 0 && height > 0)
            ratio = height / width;
    }
    float height(float width, float fallback) { return ratio > 0 ? width * ratio : fallback; }
    float[] crop(float width, float visibleHeight) {
        float sy = height(width, visibleHeight) / Math.max(1, visibleHeight);
        return new float[]{1,0,0,0, 0,sy,0,0, 0,0,1,0, 0,1-sy,0,1};
    }
}
