# FCM Anchor

Fixes missing and delayed push notifications (WhatsApp, Telegram, Gmail, …) on Xiaomi / Redmi / POCO phones running a **China ROM** with Google services installed. No root, no Shizuku. ADB is only needed once, to install.

## The problem

On HyperOS China ROMs, Xiaomi's freezer (Greezer) freezes **Google Play services**. Play services holds the single push connection (FCM) that almost every app relies on, so while it is frozen nothing arrives — messages, and calls from WhatsApp or Telegram, show up only when you unlock the phone or open the app.

Greezer skips packages listed in the system setting `MILLET_NO_RESTRICT_APP`. Xiaomi's PowerKeeper rebuilds that list after every app install/update and battery-setting change, and Play services is never on it. Adding it by hand over ADB works until the next rebuild.

## What it does

FCM Anchor runs a small foreground service that watches two settings and puts Play services back within milliseconds of Xiaomi removing it:

| Setting | Entries kept | Why |
|---|---|---|
| `MILLET_NO_RESTRICT_APP` | `com.google.android.gms`, `com.google.android.gsf`, FCM Anchor itself | Main freezer exemption |
| `com.miui.game.allowlist` | `com.google.android.gms` | Second gate with no nighttime rule — covers the HyperOS 4 overnight freeze |

After a repair it sends Xiaomi's thaw broadcast so an already-frozen Play services wakes up. Both lists match by package name, so **Dual Apps** (second WhatsApp) are covered too.

- No internet permission, no polling (event-driven), no data collection.
- The status screen is read-only; unlike the original PushGuard, no other app can use FCM Anchor to add itself to the exemption list.
- Existing list entries are always kept.

## Install

Requirements: a Mac/PC with [platform-tools](https://developer.android.com/tools/releases/platform-tools) (`adb`), and on the phone, **Developer options → USB debugging** and **Install via USB** (needs a Mi account and SIM).

1. Download `FcmAnchor.apk` from [Releases](../../releases), or build it (below).
2. Connect the phone and run:
   ```sh
   scripts/install.sh FcmAnchor.apk
   ```
   Or manually: `adb install --bypass-low-target-sdk-block FcmAnchor.apk`, then open the app once.
3. On the phone: **Settings → Battery → FCM Anchor → No restrictions**.
4. Verify: the app shows every entry as `[on list]`, and dialing `*#*#426#*#*` shows FCM as **Connected**.

Android warns that the app was built for an older version. That is expected: only apps targeting API 22 or lower may write these Xiaomi settings, which is why the install needs the bypass flag.

A low-priority "FCM Anchor is keeping notifications alive" notification stays in the shade; that is the foreground service.

## Extra: one-off ADB fix

`scripts/hyperos-push-fix.sh` applies the full fix over ADB, including runtime freezer flags an app cannot set (`dumpsys greezer IM GMS disable`, the sleep-mode network cut, and a reconnect for the Dual Apps space). Those runtime flags reset on reboot; re-run the script if notifications degrade.

## Build

Needs a JDK (17+) and the Android SDK (build-tools + a platform), e.g. from Android Studio.

```sh
# one-time: create a signing key, password in macOS Keychain
security add-generic-password -a "$USER" -s fcm-anchor-keystore -w "<password>"
keytool -genkeypair -keystore ~/keys/fcm-anchor.keystore -storetype PKCS12 \
  -alias fcm-anchor -keyalg RSA -keysize 4096 -validity 36500 -dname "CN=<you>"

scripts/build.sh      # -> build/FcmAnchor.apk
scripts/install.sh
```

`build.sh` reads `ANDROID_HOME`, `KEYSTORE`, `KEYSTORE_PASS` and `KEY_ALIAS` if set.

## Tested on

- Xiaomi 17 Pro (`pandora`), China ROM OS4.0.5.0 (HyperOS 4, Android 17), including Dual Apps WhatsApp.

The original PushGuard was tested on a Xiaomi 14 Ultra (HyperOS 3).

## Limits

- Normal-priority pushes can still wait for Android's Doze maintenance window, same as on any phone.
- A HyperOS update could rename these settings or change the freezer logic.
- After a factory reset you need ADB again to reinstall.

## Credits

Based on [PushGuard](https://github.com/waleed46shah/hyperos-cn-notification-fix) by waleed46shah (MIT). Freezer internals from the research in [kingwatam/hyperos-gms-fcm-fix](https://github.com/kingwatam/hyperos-gms-fcm-fix) and [dingwen07/hyperos-fcm-fix](https://github.com/dingwen07/hyperos-fcm-fix). Not affiliated with Xiaomi or Google.
