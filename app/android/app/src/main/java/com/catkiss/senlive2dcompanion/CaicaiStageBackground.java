package com.catkiss.senlive2dcompanion;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.opengl.GLES20;
import android.opengl.EGL14;
import android.opengl.GLUtils;
import android.util.Log;

import java.io.IOException;
import java.io.InputStream;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;

/** Host backdrop in the same surface as the portrait; all methods run on its GL thread. */
final class CaicaiStageBackground {
    interface ImageLoader { Bitmap load(String asset) throws IOException; }

    private final ImageLoader loader;
    private final FloatBuffer quad = ByteBuffer.allocateDirect(16 * 4)
            .order(ByteOrder.nativeOrder()).asFloatBuffer();
    private String requestedAsset = "";
    private String attemptedAsset;
    private int texture, program, imageWidth, imageHeight;
    private int quadWidth, quadHeight;
    private float quadSceneHeight;
    private int imageUniform;
    private int loads, uploads;
    private volatile String diagnostic = "disabled";

    CaicaiStageBackground(Context context) {
        this(asset -> {
            try (InputStream input = context.getAssets().open("flutter_assets/" + asset)) {
                return BitmapFactory.decodeStream(input);
            }
        });
    }

    CaicaiStageBackground(ImageLoader loader) { this.loader = loader; }

    void setAsset(String asset) { requestedAsset = asset == null ? "" : asset; }
    String diagnostics() { return diagnostic; }

    void contextCreated() {
        // Old names belonged to the lost context. Never delete them in a new one.
        texture = program = 0;
        attemptedAsset = null;
    }

    void draw(int width, int height, float sceneHeight) {
        if (requestedAsset.isEmpty() || width <= 0 || height <= 0) return;
        // Even a missing packaged image must not reveal an unrelated old Flutter buffer.
        GLES20.glClearColor(.075f, .065f, .09f, 1f);
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT);
        if (!requestedAsset.equals(attemptedAsset)) load();
        if (texture == 0) return;
        try {
            if (program == 0) {
                program = createProgram();
                imageUniform = GLES20.glGetUniformLocation(program, "image");
            }
            float canvasHeight = sceneHeight > 0 ? sceneHeight : height;
            if (quadWidth != width || quadHeight != height || quadSceneHeight != canvasHeight) {
                float scale = Math.max(width / (float) imageWidth, canvasHeight / imageHeight);
                float u0 = (1f - width / (imageWidth * scale)) * .5f;
                float v0 = (1f - canvasHeight / (imageHeight * scale)) * .5f;
                float v1 = v0 + height / (imageHeight * scale);
                quad.clear();
                quad.put(new float[] {-1,-1,u0,v1, 1,-1,1-u0,v1,
                                      -1,1,u0,v0, 1,1,1-u0,v0}).position(0);
                quadWidth = width; quadHeight = height; quadSceneHeight = canvasHeight;
            }
            GLES20.glViewport(0, 0, width, height);
            GLES20.glDisable(GLES20.GL_BLEND);
            GLES20.glDisable(GLES20.GL_DEPTH_TEST);
            GLES20.glDisable(GLES20.GL_SCISSOR_TEST);
            GLES20.glDisable(GLES20.GL_STENCIL_TEST);
            GLES20.glDisable(GLES20.GL_CULL_FACE);
            GLES20.glColorMask(true, true, true, true);
            GLES20.glUseProgram(program);
            GLES20.glActiveTexture(GLES20.GL_TEXTURE0);
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texture);
            GLES20.glUniform1i(imageUniform, 0);
            GLES20.glBindBuffer(GLES20.GL_ARRAY_BUFFER, 0);
            GLES20.glEnableVertexAttribArray(0);
            GLES20.glEnableVertexAttribArray(1);
            quad.position(0);
            GLES20.glVertexAttribPointer(0, 2, GLES20.GL_FLOAT, false, 16, quad);
            quad.position(2);
            GLES20.glVertexAttribPointer(1, 2, GLES20.GL_FLOAT, false, 16, quad);
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4);
        } catch (RuntimeException error) {
            diagnostic = "error asset=" + requestedAsset + " detail=" + error.getMessage();
            Log.e("CaicaiBackground", diagnostic, error);
            deleteTexture();
        } finally {
            // Give Cubism the same clean premultiplied-alpha state as the original renderer.
            GLES20.glDisableVertexAttribArray(0);
            GLES20.glDisableVertexAttribArray(1);
            GLES20.glUseProgram(0);
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, 0);
            GLES20.glEnable(GLES20.GL_BLEND);
            GLES20.glBlendFunc(GLES20.GL_ONE, GLES20.GL_ONE_MINUS_SRC_ALPHA);
        }
    }

    private void load() {
        deleteTexture();
        attemptedAsset = requestedAsset;
        Bitmap bitmap = null;
        try {
            loads++;
            bitmap = loader.load(requestedAsset);
            if (bitmap == null) throw new IOException("image decode failed");
            imageWidth = bitmap.getWidth(); imageHeight = bitmap.getHeight();
            quadWidth = quadHeight = 0;
            int[] name = new int[1];
            GLES20.glGenTextures(1, name, 0);
            texture = name[0];
            GLES20.glActiveTexture(GLES20.GL_TEXTURE0);
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texture);
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR);
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR);
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE);
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE);
            GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bitmap, 0);
            uploads++;
            diagnostic = "ready asset=" + requestedAsset + " image=" + imageWidth + "x" + imageHeight
                    + " loads=" + loads + " uploads=" + uploads + " opaque=true";
        } catch (IOException | RuntimeException error) {
            diagnostic = "error asset=" + requestedAsset + " loads=" + loads + " detail=" + error.getMessage();
            Log.e("CaicaiBackground", diagnostic, error);
            deleteTexture();
        } finally {
            if (bitmap != null) bitmap.recycle();
        }
    }

    private static int createProgram() {
        int vertex = shader(GLES20.GL_VERTEX_SHADER,
                "attribute vec2 position; attribute vec2 uv; varying vec2 sampleUv;"
                + "void main(){gl_Position=vec4(position,0.0,1.0);sampleUv=uv;}");
        int fragment = 0, result = 0;
        try {
            fragment = shader(GLES20.GL_FRAGMENT_SHADER,
                    "precision mediump float; varying vec2 sampleUv; uniform sampler2D image;"
                    + "void main(){gl_FragColor=vec4(texture2D(image,sampleUv).rgb,1.0);}");
            result = GLES20.glCreateProgram();
            GLES20.glAttachShader(result, vertex); GLES20.glAttachShader(result, fragment);
            GLES20.glBindAttribLocation(result, 0, "position");
            GLES20.glBindAttribLocation(result, 1, "uv");
            GLES20.glLinkProgram(result);
            int[] status = new int[1];
            GLES20.glGetProgramiv(result, GLES20.GL_LINK_STATUS, status, 0);
            if (status[0] == 0) throw new IllegalStateException(GLES20.glGetProgramInfoLog(result));
            return result;
        } catch (RuntimeException error) {
            if (result != 0) GLES20.glDeleteProgram(result);
            throw error;
        } finally {
            GLES20.glDeleteShader(vertex);
            if (fragment != 0) GLES20.glDeleteShader(fragment);
        }
    }

    private static int shader(int type, String source) {
        int result = GLES20.glCreateShader(type);
        GLES20.glShaderSource(result, source); GLES20.glCompileShader(result);
        int[] status = new int[1];
        GLES20.glGetShaderiv(result, GLES20.GL_COMPILE_STATUS, status, 0);
        if (status[0] != 0) return result;
        String error = GLES20.glGetShaderInfoLog(result);
        GLES20.glDeleteShader(result);
        throw new IllegalStateException(error);
    }

    private void deleteTexture() {
        if (texture != 0) GLES20.glDeleteTextures(1, new int[] {texture}, 0);
        texture = 0;
    }

    void release() {
        // dispose() may follow a detach that already destroyed the EGL context.
        if (EGL14.EGL_NO_CONTEXT.equals(EGL14.eglGetCurrentContext())) {
            texture = program = 0;
            return;
        }
        deleteTexture();
        if (program != 0) GLES20.glDeleteProgram(program);
        program = 0;
    }
}
