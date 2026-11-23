package dev.littlewhale.ar;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.SharedPreferences;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.InsetDrawable;
import android.graphics.drawable.RippleDrawable;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.TextView;

/** Use the running Flutter theme, including its generated Material color scheme. */
public final class CompanionArStyle {
    private final Activity activity;
    private final SharedPreferences theme;

    CompanionArStyle(Activity activity) {
        this.activity = activity;
        theme = activity.getSharedPreferences("companion_ar_theme", Activity.MODE_PRIVATE);
    }

    int color(String key) {
        return theme.getInt(key, key.equals("surface") ? Color.BLACK : Color.WHITE);
    }

    private int dp(int amount) {
        return Math.round(amount * activity.getResources().getDisplayMetrics().density);
    }

    private GradientDrawable shape(int fill, int radius) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(fill);
        drawable.setCornerRadius(dp(radius));
        return drawable;
    }

    void panel(View root, Button primary) {
        root.setBackgroundColor(color("surface"));
        activity.getWindow().setStatusBarColor(color("surface"));
        activity.getWindow().setNavigationBarColor(color("surface"));
        styleControls(root, primary);
    }

    private void styleControls(View view, Button primary) {
        if (view instanceof Button) {
            Button button = (Button) view;
            boolean filled = button == primary;
            int fg = color(filled ? "onPrimary" : "onTonal");
            int bg = color(filled ? "primary" : "tonal");
            int[][] states = {{-android.R.attr.state_enabled}, {}};
            GradientDrawable pill = shape(bg, 100);
            pill.setColor(new ColorStateList(states, new int[]{color("tonal"), bg}));
            RippleDrawable ripple = new RippleDrawable(ColorStateList.valueOf(
                (fg & 0x00ffffff) | 0x24000000), pill, null);
            button.setBackgroundTintList(null);
            button.setBackground(new InsetDrawable(ripple, dp(3), dp(3), dp(3), dp(3)));
            button.setTextColor(new ColorStateList(states, new int[]{color("secondaryText"), fg}));
            button.setAllCaps(false);
            button.setTextSize(14);
            button.setMinHeight(dp(48));
        } else if (view instanceof TextView) {
            ((TextView) view).setTextColor(color("secondaryText"));
        } else if (view instanceof ViewGroup && !(view instanceof android.webkit.WebView)) {
            ViewGroup group = (ViewGroup) view;
            for (int i = 0; i < group.getChildCount(); i++) styleControls(group.getChildAt(i), primary);
        }
    }

    AlertDialog.Builder dialog() {
        return new AlertDialog.Builder(activity) {
            @Override public AlertDialog show() {
                AlertDialog dialog = super.show();
                dialog.getWindow().setBackgroundDrawable(new InsetDrawable(shape(color("surface"), 28), dp(12)));
                for (int which : new int[]{-1, -2, -3}) {
                    Button button = dialog.getButton(which);
                    if (button != null) button.setTextColor(color("primary"));
                }
                return dialog;
            }
        };
    }
}
