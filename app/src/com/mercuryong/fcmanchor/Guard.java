package com.mercuryong.fcmanchor;

import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.provider.Settings;
import android.util.Log;

import java.util.LinkedHashSet;
import java.util.Set;

/**
 * Keeps Google Play services exempt from HyperOS CN's freezer (Greezer).
 *
 * MILLET_NO_RESTRICT_APP: the main exemption. PowerKeeper rebuilds it on package
 * and battery-setting changes and drops Play services each time.
 * com.miui.game.allowlist: a second gate with no nighttime rule (HyperOS 4).
 * Game predownload components may rewrite it.
 *
 * Both entries are matched by package name, so they also cover Dual Apps (user 999).
 */
final class Guard {
    static final String TAG = "FcmAnchor";
    static final String MILLET_KEY = "MILLET_NO_RESTRICT_APP";
    static final String GAME_KEY = "com.miui.game.allowlist";
    static final String GMS = "com.google.android.gms";
    static final String GSF = "com.google.android.gsf";

    static final String OK = "ok";
    static final String REPAIRED = "repaired";

    private Guard() {
    }

    static SharedPreferences prefs(Context c) {
        return c.getSharedPreferences("fcmanchor", Context.MODE_PRIVATE);
    }

    static String[] milletTargets(Context c) {
        return new String[]{GMS, GSF, c.getPackageName()};
    }

    static String[] gameTargets() {
        return new String[]{GMS};
    }

    /** Re-adds any missing target to both lists. Returns a short status line. */
    static synchronized String ensure(Context c, String why) {
        ContentResolver r = c.getContentResolver();
        String millet = ensureList(r, MILLET_KEY, ",", ", ", milletTargets(c));
        String game = ensureList(r, GAME_KEY, "_", "_", gameTargets());
        boolean repaired = REPAIRED.equals(millet) || REPAIRED.equals(game);
        if (repaired) {
            thaw(c);
        }

        String result = "millet=" + millet + " game=" + game;
        Log.i(TAG, why + " -> " + result);
        SharedPreferences p = prefs(c);
        SharedPreferences.Editor ed = p.edit()
                .putLong("last_time", System.currentTimeMillis())
                .putString("last_why", why)
                .putString("last_result", result);
        if (repaired) {
            ed.putInt("repairs", p.getInt("repairs", 0) + 1);
        }
        ed.apply();
        return result;
    }

    private static String ensureList(ContentResolver r, String key, String sep, String joiner, String[] targets) {
        Set<String> list = read(r, key, sep);
        boolean changed = false;
        for (String t : targets) {
            changed |= list.add(t);
        }
        if (!changed) {
            return OK;
        }
        try {
            return Settings.System.putString(r, key, join(list, joiner)) ? REPAIRED : "write returned false";
        } catch (RuntimeException e) {
            return "write failed: " + e.getClass().getSimpleName();
        }
    }

    /** Restoring an exemption does not thaw a frozen process; this Xiaomi system receiver does. */
    private static void thaw(Context c) {
        try {
            c.sendBroadcast(new Intent("com.xiaomi.mipush.REFRESH_WHITE_LIST_ACTION")
                    .setPackage("android")
                    .putExtra("pkgName", GMS)
                    .putExtra("option", -1));
        } catch (RuntimeException e) {
            Log.w(TAG, "thaw failed: " + e.getClass().getSimpleName());
        }
    }

    static Set<String> read(ContentResolver r, String key, String sep) {
        Set<String> out = new LinkedHashSet<String>();
        String value = Settings.System.getString(r, key);
        if (value == null || value.equals("null")) {
            return out;
        }
        for (String s : value.split(sep)) {
            String t = s.trim();
            if (t.length() > 0) {
                out.add(t);
            }
        }
        return out;
    }

    static String join(Set<String> items, String joiner) {
        StringBuilder sb = new StringBuilder();
        for (String s : items) {
            if (sb.length() > 0) {
                sb.append(joiner);
            }
            sb.append(s);
        }
        return sb.toString();
    }
}
