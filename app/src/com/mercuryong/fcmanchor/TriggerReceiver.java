package com.mercuryong.fcmanchor;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/** Starts the guard after boot, self-update, and any package change (when PowerKeeper rebuilds its list). */
public class TriggerReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent != null ? intent.getAction() : null;
        if (Intent.ACTION_BOOT_COMPLETED.equals(action)
                || Intent.ACTION_MY_PACKAGE_REPLACED.equals(action)
                || Intent.ACTION_PACKAGE_ADDED.equals(action)
                || Intent.ACTION_PACKAGE_REPLACED.equals(action)
                || Intent.ACTION_PACKAGE_REMOVED.equals(action)) {
            GuardService.start(context, action);
        }
    }
}
