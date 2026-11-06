package com.mercuryong.fcmanchor;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.database.ContentObserver;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.provider.Settings;

/** Foreground service that repairs both lists the moment either is rewritten. No polling. */
public class GuardService extends Service {
    private static final String CHANNEL = "guard";
    private ContentObserver observer;

    static void start(Context c, String why) {
        c.startForegroundService(new Intent(c, GuardService.class).putExtra("why", why));
    }

    @Override
    public void onCreate() {
        super.onCreate();
        goForeground();
        observer = new ContentObserver(new Handler(Looper.getMainLooper())) {
            @Override
            public void onChange(boolean selfChange) {
                Guard.ensure(GuardService.this, "list changed");
            }
        };
        getContentResolver().registerContentObserver(Settings.System.getUriFor(Guard.MILLET_KEY), false, observer);
        getContentResolver().registerContentObserver(Settings.System.getUriFor(Guard.GAME_KEY), false, observer);
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        String why = intent != null ? intent.getStringExtra("why") : null;
        Guard.ensure(this, why != null ? why : "service restart");
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        if (observer != null) {
            getContentResolver().unregisterContentObserver(observer);
        }
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    private void goForeground() {
        NotificationChannel ch = new NotificationChannel(CHANNEL, "Background guard", NotificationManager.IMPORTANCE_MIN);
        ch.setShowBadge(false);
        ((NotificationManager) getSystemService(NOTIFICATION_SERVICE)).createNotificationChannel(ch);
        Notification n = new Notification.Builder(this, CHANNEL)
                .setSmallIcon(android.R.drawable.stat_notify_sync)
                .setContentTitle("FCM Anchor is keeping notifications alive")
                .setOngoing(true)
                .build();
        startForeground(1, n);
    }
}
