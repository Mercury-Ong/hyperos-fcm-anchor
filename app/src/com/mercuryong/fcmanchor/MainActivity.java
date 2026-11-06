package com.mercuryong.fcmanchor;

import android.app.Activity;
import android.os.Bundle;
import android.widget.ScrollView;
import android.widget.TextView;

import java.text.DateFormat;
import java.util.Date;
import java.util.Set;

/** Read-only status screen. Opening it runs a check and (re)starts the guard. */
public class MainActivity extends Activity {
    private TextView text;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        text = new TextView(this);
        int pad = (int) (20 * getResources().getDisplayMetrics().density);
        text.setPadding(pad, pad, pad, pad);
        text.setTextSize(15);
        text.setTextIsSelectable(true);
        ScrollView scroll = new ScrollView(this);
        scroll.addView(text);
        setContentView(scroll);
    }

    @Override
    protected void onResume() {
        super.onResume();
        String result = Guard.ensure(this, "app opened");
        GuardService.start(this, "app opened");
        render(result);
    }

    private void render(String result) {
        Set<String> millet = Guard.read(getContentResolver(), Guard.MILLET_KEY, ",");
        Set<String> game = Guard.read(getContentResolver(), Guard.GAME_KEY, "_");
        StringBuilder sb = new StringBuilder("FCM Anchor\n\nCheck: ").append(result).append("\n\n");
        sb.append("No-restrict list (").append(Guard.MILLET_KEY).append("):\n");
        for (String p : Guard.milletTargets(this)) {
            sb.append(millet.contains(p) ? "  [on list]  " : "  [MISSING]  ").append(p).append('\n');
        }
        sb.append("\nGame allowlist (").append(Guard.GAME_KEY).append("):\n");
        for (String p : Guard.gameTargets()) {
            sb.append(game.contains(p) ? "  [on list]  " : "  [MISSING]  ").append(p).append('\n');
        }
        long t = Guard.prefs(this).getLong("last_time", 0);
        sb.append("\nLast check: ")
                .append(t == 0 ? "never" : DateFormat.getDateTimeInstance().format(new Date(t)))
                .append(" (").append(Guard.prefs(this).getString("last_why", "-")).append(")\n")
                .append("Repairs: ").append(Guard.prefs(this).getInt("repairs", 0)).append('\n');
        text.setText(sb.toString());
    }
}
