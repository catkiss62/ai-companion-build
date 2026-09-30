package com.catkiss.senlive2dcompanion;

import android.graphics.Bitmap;
import android.graphics.Color;
import android.opengl.EGL14;
import android.opengl.EGLConfig;
import android.opengl.EGLContext;
import android.opengl.EGLDisplay;
import android.opengl.EGLSurface;
import android.opengl.GLES20;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import java.io.IOException;
import java.nio.ByteBuffer;
import org.junit.Test;
import org.junit.runner.RunWith;
import static org.junit.Assert.*;

/** Real ES2 pixels: backdrop opacity, orientation, keyboard crop and retained texture. */
@RunWith(AndroidJUnit4.class)
public class CaicaiBackgroundSmokeTest {
    @Test public void opaqueDayNightAndResizeKeepTextureUntilContextLoss() {
        int[] loads = {0};
        CaicaiStageBackground backdrop = new CaicaiStageBackground(asset -> {
            loads[0]++;
            Bitmap bitmap = Bitmap.createBitmap(4, 4, Bitmap.Config.ARGB_8888);
            for (int y = 0; y < 4; y++) for (int x = 0; x < 4; x++) {
                bitmap.setPixel(x, y, asset.equals("night") ? Color.GREEN
                        : y < 2 ? Color.RED : Color.BLUE);
            }
            return bitmap;
        });
        try (GlContext gl = new GlContext()) {
            backdrop.setAsset("day");
            backdrop.draw(4, 4, 4);
            assertPixel(0, 3, 255, 0, 0, 255);
            assertPixel(0, 0, 0, 0, 255, 255);
            for (int i = 0; i < 10; i++) backdrop.draw(4, 4, 4);
            assertEquals(1, loads[0]);
            backdrop.setAsset("day");
            // Keyboard crops the bottom of the original scene; it must not squeeze the image.
            backdrop.draw(4, 2, 4);
            assertPixel(0, 0, 255, 0, 0, 255);
            assertEquals(1, loads[0]);
            backdrop.draw(4, 4, 4);
            assertPixel(0, 0, 0, 0, 255, 255);
            backdrop.setAsset("night");
            backdrop.draw(4, 4, 4);
            assertPixel(0, 0, 0, 255, 0, 255);
            assertEquals(2, loads[0]);
            assertEquals(GLES20.GL_NO_ERROR, GLES20.glGetError());
        }
        try (GlContext gl = new GlContext()) {
            backdrop.contextCreated();
            backdrop.draw(4, 4, 4);
            assertPixel(0, 3, 0, 255, 0, 255);
            assertEquals(3, loads[0]);
            backdrop.release();
        }
    }

    @Test public void missingImageIsOpaqueAndDoesNotRetryEveryFrame() {
        try (GlContext gl = new GlContext()) {
            int[] loads = {0};
            CaicaiStageBackground backdrop = new CaicaiStageBackground(asset -> {
                loads[0]++; throw new IOException("missing fixture");
            });
            GLES20.glClearColor(1, 0, 0, 0);
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT);
            backdrop.draw(4, 4, 4);
            assertEquals(0, pixel(0, 0)[3]); // No backdrop requested: standalone remains transparent.
            backdrop.setAsset("day");
            for (int i = 0; i < 10; i++) backdrop.draw(4, 4, 4);
            assertEquals(255, pixel(0, 0)[3]);
            assertEquals(1, loads[0]);
            assertTrue(backdrop.diagnostics(), backdrop.diagnostics().contains("error asset=day"));
            assertEquals(GLES20.GL_NO_ERROR, GLES20.glGetError());
            backdrop.release();
        }
    }

    private static int[] pixel(int x, int y) {
        ByteBuffer pixel = ByteBuffer.allocateDirect(4);
        GLES20.glReadPixels(x, y, 1, 1, GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, pixel);
        return new int[] {pixel.get(0) & 255, pixel.get(1) & 255, pixel.get(2) & 255, pixel.get(3) & 255};
    }

    private static void assertPixel(int x, int y, int red, int green, int blue, int alpha) {
        assertArrayEquals(new int[] {red, green, blue, alpha}, pixel(x, y));
    }

    private static final class GlContext implements AutoCloseable {
        final EGLDisplay display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY);
        final EGLContext context;
        final EGLSurface surface;
        GlContext() {
            assertTrue(EGL14.eglInitialize(display, new int[2], 0, new int[2], 0));
            EGLConfig[] configs = new EGLConfig[1];
            assertTrue(EGL14.eglChooseConfig(display, new int[] {
                    EGL14.EGL_RED_SIZE,8,EGL14.EGL_GREEN_SIZE,8,EGL14.EGL_BLUE_SIZE,8,
                    EGL14.EGL_ALPHA_SIZE,8,EGL14.EGL_RENDERABLE_TYPE,EGL14.EGL_OPENGL_ES2_BIT,
                    EGL14.EGL_SURFACE_TYPE,EGL14.EGL_PBUFFER_BIT,EGL14.EGL_NONE},
                    0, configs, 0, 1, new int[1], 0));
            context = EGL14.eglCreateContext(display, configs[0], EGL14.EGL_NO_CONTEXT,
                    new int[] {EGL14.EGL_CONTEXT_CLIENT_VERSION,2,EGL14.EGL_NONE}, 0);
            surface = EGL14.eglCreatePbufferSurface(display, configs[0],
                    new int[] {EGL14.EGL_WIDTH,4,EGL14.EGL_HEIGHT,4,EGL14.EGL_NONE}, 0);
            assertTrue(EGL14.eglMakeCurrent(display, surface, surface, context));
        }
        @Override public void close() {
            EGL14.eglMakeCurrent(display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT);
            EGL14.eglDestroySurface(display, surface);
            EGL14.eglDestroyContext(display, context);
            EGL14.eglTerminate(display);
        }
    }
}
