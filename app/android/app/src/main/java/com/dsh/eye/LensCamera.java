package com.dsh.eye;

import android.app.Activity;
import android.graphics.Bitmap;
import android.os.SystemClock;
import android.widget.ImageView;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

/** One object owns one camera generation. No frames are written to disk. */
public final class LensCamera implements CameraEngine.Sink {
    private static final int WIDTH = 240, HEIGHT = 320;
    private final Activity activity;
    private final ImageView preview;
    private final CameraEngine camera;
    private final CallStream stream = new CallStream();
    private final AtomicBoolean previewQueued = new AtomicBoolean();
    private final int[] pixels = new int[WIDTH * HEIGHT];
    private final long opened = SystemClock.elapsedRealtime();
    private volatile boolean active = true;
    private volatile String status = "正在打开相机";
    private byte[] rgb, latest, previousSheet;
    private long lastFrame, sheetAt, batches, frames;
    private boolean firstTravel = true;
    private boolean pendingChange;

    public LensCamera(Activity activity, ImageView preview) {
        this.activity = activity;
        this.preview = preview;
        Pipeline.Opts opts = new Pipeline.Opts();
        opts.width = WIDTH;
        opts.height = HEIGHT;
        opts.timeNormalizeFrames = true;
        stream.open(opts, 12, 1);
        camera = new CameraEngine(activity, this);
        camera.start();
    }

    @Override public void onPreviewBitmap(Bitmap bitmap) {
        if (!active) { bitmap.recycle(); return; }
        Bitmap scaled = Bitmap.createScaledBitmap(bitmap, WIDTH, HEIGHT, true);
        scaled.getPixels(pixels, 0, WIDTH, 0, 0, WIDTH, HEIGHT);
        if (scaled != bitmap) scaled.recycle();
        byte[] color = new byte[pixels.length * 3];
        int i = 0;
        for (int pixel : pixels) {
            color[i++] = (byte)(pixel >> 16);
            color[i++] = (byte)(pixel >> 8);
            color[i++] = (byte)pixel;
        }
        rgb = color;
        if (!previewQueued.compareAndSet(false, true)) { bitmap.recycle(); return; }
        activity.runOnUiThread(() -> {
            previewQueued.set(false);
            if (active) preview.setImageBitmap(bitmap);
            else bitmap.recycle();
        });
    }

    @Override public synchronized void onJpeg(byte[] jpeg, int w, int h, int rotation) {
        long now = SystemClock.elapsedRealtime();
        byte[] score = rgb;
        rgb = null;
        if (!active || score == null || jpeg == null || now - opened < CallCapture.WARMUP_MS) return;
        frames++;
        latest = jpeg;
        lastFrame = now;
        stream.push(System.currentTimeMillis(), score, jpeg);
        if (!stream.ready()) return;
        Pipeline.Sheet sheet = stream.take();
        if (sheet == null) return;
        boolean changed = false;
        for (Pipeline.Entry frame : sheet.frames) {
            if ("mark".equals(frame.via) || "cut".equals(frame.via) || "start".equals(frame.via)) changed = true;
        }
        if (changed) {
            byte[] packed = Sheet.compose(sheet);
            if (packed != null) {
                previousSheet = packed;
                sheetAt = now;
                pendingChange = true;
                batches++;
            }
        }
    }

    @Override public void onEngineState(String message) { status = message; }

    /** Called on a worker, including user-triggered JPEG composition. */
    public synchronized Map<String,Object> take(boolean user, boolean statsOnly) {
        Map<String,Object> reply = new HashMap<>();
        reply.put("status", status);
        reply.put("frames", frames);
        reply.put("batches", batches);
        if (statsOnly || !active || latest == null || SystemClock.elapsedRealtime() - lastFrame > 2200) return reply;
        if (!user && !firstTravel && !pendingChange) return reply;
        byte[] context = SystemClock.elapsedRealtime() - sheetAt <= 60000 ? previousSheet : null;
        if (user) {
            Pipeline.Sheet current = stream.takeNow(System.currentTimeMillis(), "user");
            if (current != null && current.frames.size() > 1) {
                byte[] composed = Sheet.compose(current);
                if (composed != null) context = composed;
            }
        }
        reply.put("frame", latest);
        if (context != null) reply.put("sheet", context);
        pendingChange = false;
        firstTravel = false;
        return reply;
    }

    public void stop() {
        active = false;
        camera.stop();
        preview.setImageDrawable(null);
        // Camera and its bounded pipeline become unreachable after queued callbacks finish.
    }
}
