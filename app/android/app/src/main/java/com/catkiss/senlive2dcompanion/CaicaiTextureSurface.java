package com.catkiss.senlive2dcompanion;

import android.content.Context;
import android.graphics.SurfaceTexture;
import android.opengl.*;
import android.os.Handler;
import android.os.HandlerThread;
import android.util.AttributeSet;
import android.view.TextureView;

/** One EGL owner for the lifetime of a chat stage. Window surfaces may come and go;
 * the context, Cubism models and uploaded textures survive route/foreground changes.
 * All EGL calls and queued model mutations run on this thread, never the IME thread. */
class CaicaiTextureSurface extends TextureView implements TextureView.SurfaceTextureListener {
    // CubismFramework and its shader registry are process globals. A replacement
    // view waits on its GL thread, never the UI thread, until the old owner releases.
    private static final java.util.concurrent.Semaphore FRAMEWORK_OWNER = new java.util.concurrent.Semaphore(1,true);
    private boolean frameworkLease;
    final boolean ownsRendererContext() { return frameworkLease && contexts > 0; }
    static final int RENDERMODE_WHEN_DIRTY = 0, RENDERMODE_CONTINUOUSLY = 1;
    private final HandlerThread thread = new HandlerThread("CaicaiGL");
    private final Handler gl;
    private GLSurfaceView.Renderer renderer;
    private EGLDisplay display = EGL14.EGL_NO_DISPLAY;
    private EGLContext context = EGL14.EGL_NO_CONTEXT;
    private EGLSurface window = EGL14.EGL_NO_SURFACE, parking = EGL14.EGL_NO_SURFACE;
    private EGLConfig config;
    private SurfaceTexture texture;
    private volatile int contexts, surfaces;
    private volatile long frames;
    String surfaceDiagnostics() { return "texture_egl contexts="+contexts+" surfaces="+surfaces+" frames="+frames; }
    private boolean paused, closed, scheduled;
    private volatile int mode = RENDERMODE_CONTINUOUSLY;
    CaicaiTextureSurface(Context ctx, AttributeSet attrs) {
        super(ctx, attrs); setOpaque(false); thread.start(); gl = new Handler(thread.getLooper());
        setSurfaceTextureListener(this);
    }
    void setRenderer(GLSurfaceView.Renderer value) { renderer = value; }
    public void setRenderMode(int value) { mode = value; requestRender(); }
    public int getRenderMode() { return mode; }
    public void queueEvent(Runnable command) { gl.post(() -> {
        if (!closed) try { command.run(); } catch (Throwable failure) { onSurfaceFailure(failure); }
    }); }
    public void requestRender() { gl.post(this::schedule); }
    public void onResume() { gl.post(() -> { paused = false; schedule(); }); }
    public void onPause() { gl.post(() -> { paused = true; gl.removeCallbacks(frame); scheduled = false; }); }
    protected void onSurfaceFailure(Throwable failure) { android.util.Log.e("CaicaiGL", "surface", failure); }
    private void schedule() {
        if (!closed && !paused && window != EGL14.EGL_NO_SURFACE && !scheduled) {
            scheduled = true; gl.post(frame);
        }
    }
    private final Runnable frame = new Runnable() {
        public void run() {
            scheduled = false;
            if (closed || paused || window == EGL14.EGL_NO_SURFACE) return;
            long start = android.os.SystemClock.uptimeMillis();
            try {
                renderer.onDrawFrame(null); frames++;
                if (!EGL14.eglSwapBuffers(display, window)) {
                    int error = EGL14.eglGetError();
                    if (error == EGL14.EGL_CONTEXT_LOST) {
                        // Real driver context loss is exceptional, observable, and rebuilt once.
                        SurfaceTexture saved = texture;
                        int w = getWidth(), h = getHeight();
                        destroyEgl(); attach(saved, w, h); return;
                    }
                    throw new IllegalStateException("eglSwapBuffers: " + error);
                }
            } catch (Throwable failure) { onSurfaceFailure(failure); return; }
            if (mode == RENDERMODE_CONTINUOUSLY) {
                scheduled = true;
                gl.postDelayed(this, Math.max(1, 33-(android.os.SystemClock.uptimeMillis()-start)));
            }
        }
    };
    private void initialize() {
        if (!frameworkLease) { FRAMEWORK_OWNER.acquireUninterruptibly(); frameworkLease = true; }
        display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY);
        if (!EGL14.eglInitialize(display, new int[2], 0, new int[2], 0)) throw new IllegalStateException("eglInitialize");
        int[] attributes = {EGL14.EGL_RED_SIZE,8,EGL14.EGL_GREEN_SIZE,8,EGL14.EGL_BLUE_SIZE,8,
            EGL14.EGL_ALPHA_SIZE,8,EGL14.EGL_DEPTH_SIZE,24,EGL14.EGL_RENDERABLE_TYPE,EGL14.EGL_OPENGL_ES2_BIT,
            EGL14.EGL_SURFACE_TYPE,EGL14.EGL_WINDOW_BIT|EGL14.EGL_PBUFFER_BIT,EGL14.EGL_NONE};
        EGLConfig[] choices = new EGLConfig[1]; int[] count = new int[1];
        if (!EGL14.eglChooseConfig(display,attributes,0,choices,0,1,count,0) || count[0]==0)
            throw new IllegalStateException("No transparent EGL config");
        config = choices[0];
        context = EGL14.eglCreateContext(display,config,EGL14.EGL_NO_CONTEXT,
            new int[]{EGL14.EGL_CONTEXT_CLIENT_VERSION,2,EGL14.EGL_NONE},0);
        parking = EGL14.eglCreatePbufferSurface(display,config,
            new int[]{EGL14.EGL_WIDTH,1,EGL14.EGL_HEIGHT,1,EGL14.EGL_NONE},0);
        if (context==EGL14.EGL_NO_CONTEXT || parking==EGL14.EGL_NO_SURFACE) throw new IllegalStateException("EGL allocation failed");
        EGL14.eglMakeCurrent(display,parking,parking,context);
        contexts++; renderer.onSurfaceCreated(null,null);
    }
    private void detachWindow() {
        gl.removeCallbacks(frame); scheduled = false;
        if (window != EGL14.EGL_NO_SURFACE) {
            EGL14.eglMakeCurrent(display,parking,parking,context);
            EGL14.eglDestroySurface(display,window); window = EGL14.EGL_NO_SURFACE;
        }
    }
    private void attach(SurfaceTexture next, int width, int height) {
        if (closed || next == null) return;
        try {
            if (context == EGL14.EGL_NO_CONTEXT) initialize();
            detachWindow(); texture = next;
            window = EGL14.eglCreateWindowSurface(display,config,next,new int[]{EGL14.EGL_NONE},0);
            if (window==EGL14.EGL_NO_SURFACE || !EGL14.eglMakeCurrent(display,window,window,context))
                throw new IllegalStateException("EGL window attach failed");
            surfaces++; renderer.onSurfaceChanged(null,width,height); schedule();
        } catch (Throwable failure) { onSurfaceFailure(failure); }
    }
    @Override public void onSurfaceTextureAvailable(SurfaceTexture surface,int width,int height) {
        gl.post(() -> attach(surface,width,height));
    }
    @Override public void onSurfaceTextureSizeChanged(SurfaceTexture surface,int width,int height) {
        gl.post(() -> { if (!closed && texture == surface && window != EGL14.EGL_NO_SURFACE) {
            renderer.onSurfaceChanged(null,width,height); schedule();
        }});
    }
    @Override public boolean onSurfaceTextureDestroyed(SurfaceTexture surface) {
        if (!gl.post(() -> { if (texture == surface) { detachWindow(); texture = null; } surface.release(); })) surface.release();
        return false; // release only after the GL thread detaches this producer.
    }
    @Override public void onSurfaceTextureUpdated(SurfaceTexture surface) { }
    private void destroyEgl() {
        detachWindow();
        if (display != EGL14.EGL_NO_DISPLAY) {
            EGL14.eglMakeCurrent(display,EGL14.EGL_NO_SURFACE,EGL14.EGL_NO_SURFACE,EGL14.EGL_NO_CONTEXT);
            if (parking != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(display,parking);
            if (context != EGL14.EGL_NO_CONTEXT) EGL14.eglDestroyContext(display,context);
            EGL14.eglTerminate(display);
        }
        display=EGL14.EGL_NO_DISPLAY; context=EGL14.EGL_NO_CONTEXT; parking=EGL14.EGL_NO_SURFACE;
    }
    void closeSurface() { gl.post(() -> {
        closed=true;
        try { destroyEgl(); }
        finally {
            if (frameworkLease) { frameworkLease=false; FRAMEWORK_OWNER.release(); }
            thread.quitSafely();
        }
    }); }
}
