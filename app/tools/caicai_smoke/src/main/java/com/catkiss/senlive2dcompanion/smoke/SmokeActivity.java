package com.catkiss.senlive2dcompanion.smoke;

import android.app.Activity;
import android.os.Bundle;
import android.widget.FrameLayout;
import com.catkiss.senlive2dcompanion.CaicaiCompanionView;

public class SmokeActivity extends Activity {
    public volatile CaicaiCompanionView view;
    public volatile Throwable error;
    public volatile String status = "";
    private FrameLayout root;
    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        root = new FrameLayout(this);
        setContentView(root);
        replaceView();
    }
    public void replaceView() {
        if (view != null) { view.release(); root.removeView(view); }
        view = new CaicaiCompanionView(this);
        view.setListener(new CaicaiCompanionView.Listener() {
            public void onStatus(String value) { status = value; }
            public void onReady(String detail) { }
            public void onError(Throwable value) { error = value; }
            public void onMotionDiagnosticStep(String s, int i, int total) { }
            public void onMotionDiagnosticComplete(String s) { }
            public void onCompositeReport(String s) { }
            public void onMaidHairPointPicked(String s, boolean front) { }
        });
        root.addView(view, new FrameLayout.LayoutParams(-1, -1));
        view.onHostResume();
    }
    @Override public void onResume() { super.onResume(); if (view != null) view.onHostResume(); }
    @Override public void onPause() { if (view != null) view.onHostPause(); super.onPause(); }
    @Override public void onDestroy() { if (view != null) view.release(); super.onDestroy(); }
}
