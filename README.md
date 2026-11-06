# FCM Anchor

Fixes missing and delayed push notifications (WhatsApp, Telegram, Gmail, …), including incoming WhatsApp and Telegram calls, on Xiaomi / Redmi / POCO phones running a **China ROM (HyperOS)** with Google services installed.

No root and no Shizuku. You need a computer with ADB once, to install it.

## The problem

On HyperOS China ROMs, Xiaomi's app freezer (Greezer) freezes **Google Play services**. Play services holds the single push connection (FCM) that almost every app relies on. While it is frozen nothing arrives: messages and calls show up only when you unlock the phone or open the app.

Greezer skips apps listed in the system setting `MILLET_NO_RESTRICT_APP`. Xiaomi's PowerKeeper rebuilds that list whenever an app is installed, updated or removed, or a battery setting changes, and Play services is never on it. Adding it by hand over ADB only lasts until the next rebuild.

## What FCM Anchor does

A small foreground service watches two settings and puts Play services back within milliseconds of Xiaomi removing it:

| Setting | Entries kept | Why |
|---|---|---|
| `MILLET_NO_RESTRICT_APP` | `com.google.android.gms`, `com.google.android.gsf`, FCM Anchor itself | Main freezer exemption |
| `com.miui.game.allowlist` | `com.google.android.gms` | Second exemption with no nighttime rule; covers the HyperOS 4 overnight freeze |

After a repair it sends Xiaomi's thaw broadcast, so a Play services that is already frozen wakes up. Both lists match by package name, so **Dual Apps** (for example a second WhatsApp) are covered too.

## Tested devices

| Phone | Codename | ROM | Android | Dual Apps | Result | Date |
|---|---|---|---|---|---|---|
| Xiaomi 17 Pro (25098PN5AC) | `pandora` | OS4.0.5.0.XBLCNXM (HyperOS 4, CN) | 17 | Yes, works | ✅ Works, survives reboot | 2026-11-06 |

The original PushGuard, which this project is based on, was tested on a Xiaomi 14 Ultra (`aurora`) on HyperOS 3 (OS3.0.306.0 and OS3.0.308.0).

**Tried it on another phone?** Run `scripts/check.sh` and open a [Device report](https://github.com/Mercury-Ong/hyperos-fcm-anchor/issues/new?template=device-report.yml), whether it worked or not. Reports get added to this table.

## Install

**You need:**
- A computer with [platform-tools](https://developer.android.com/tools/releases/platform-tools) (`adb`).
- On the phone, in **Settings → Additional settings → Developer options**:
  - **USB debugging** on.
  - **Install via USB** on. Xiaomi requires a Mi account and a SIM card for this. Go through every warning screen; if you leave early, the toggle quietly switches back off.

**Steps:**
1. Download `FcmAnchor.apk` from the [latest release](https://github.com/Mercury-Ong/hyperos-fcm-anchor/releases/latest), or [build it](#build).
2. Connect the phone, unlock it, and run:
   ```sh
   scripts/install.sh FcmAnchor.apk
   ```
   Or install it by hand:
   ```sh
   adb install --bypass-low-target-sdk-block FcmAnchor.apk
   ```
   Then open the app once.
3. Watch the phone while it installs:
   - Tap **Install** when Xiaomi asks. The prompt times out after a few seconds.
   - The first time the app opens, Xiaomi shows a **Review permissions** screen. Tap **Continue**.
4. Set **Settings → Battery → FCM Anchor → No restrictions**.
5. Check it worked:
   - The app shows every entry as `[on list]`.
   - Dialing `*#*#426#*#*` shows FCM as **Connected**.
   - Lock the phone for 10 minutes or more, then have someone message and call you.

Some things that look like errors are expected:
- Android warns that the app was built for an older version of Android. Only apps targeting Android 5.1 (API 22) or lower are allowed to write these Xiaomi settings, which is also why the install needs the bypass flag.
- A low-priority "FCM Anchor is keeping notifications alive" notification stays in the shade. That is the foreground service; it is how the app stays running.

### Check the APK is genuine

Release APKs are signed with this certificate:

```
SHA-256: 15:8C:88:5A:E9:78:34:15:60:FE:56:8A:24:65:38:C3:B7:98:B3:5E:EE:D9:5F:25:51:C6:03:F4:45:4F:5C:38
```

To check it:
```sh
apksigner verify --print-certs FcmAnchor.apk
```
`apksigner` comes with the Android SDK build-tools. Updates only install over an existing copy if they are signed with the same key.

## Permissions and privacy

| Permission | Used for |
|---|---|
| `WRITE_SETTINGS` | Writing the two Xiaomi exemption lists, nothing else |
| `RECEIVE_BOOT_COMPLETED` | Restarting after a reboot |
| `FOREGROUND_SERVICE` | Staying alive to watch the lists |

- No internet permission, so it cannot send anything anywhere.
- It collects no data and runs no ads or analytics.
- It is event-driven and never polls.
- It never removes existing entries from the lists.
- Its screen is read-only. Other apps cannot use FCM Anchor to put themselves on the exemption list, which was possible with the original PushGuard.
- It only reacts to five system broadcasts: boot, its own update, and app install, update or removal.

## Uninstall

```sh
adb uninstall com.mercuryong.fcmanchor
```

Or uninstall it from the phone like any other app. Xiaomi removes Play services from `MILLET_NO_RESTRICT_APP` on its next rebuild. The game allowlist entry stays until Xiaomi rewrites that list.

## Scripts

All scripts expect one phone connected over ADB. With several phones connected, set `ANDROID_SERIAL` to choose one.

| Script | What it does |
|---|---|
| `scripts/install.sh [apk]` | Installs the app, allows it to run in the background, and opens it once |
| `scripts/check.sh` | Read-only health check: device info, exemption lists, whether Play services is frozen, and the push connection. Paste its output into device reports |
| `scripts/hyperos-push-fix.sh` | One-off ADB fix without the app (details below) |
| `scripts/build.sh` | Builds and signs the APK |

`scripts/hyperos-push-fix.sh` applies the whole fix over ADB, including runtime freezer settings that an app is not allowed to change:
- It adds Play services to both exemption lists.
- It turns off the sleep-mode network cut.
- It disables Greezer's Play services limiter.
- It reconnects FCM, for Dual Apps too.

The freezer settings reset on reboot, so run it again if notifications get worse. With the app installed this is usually unnecessary: on the Xiaomi 17 Pro, notifications kept working after a reboot with these settings reset. `--undo` restores Xiaomi's defaults for everything it changes.

## Build

Needs a JDK (17 or newer) and the Android SDK (build-tools and one platform), for example from Android Studio.

```sh
# One time: create your own signing key, with its password in the macOS Keychain
security add-generic-password -a "$USER" -s fcm-anchor-keystore -w "<password>"
keytool -genkeypair -keystore ~/keys/fcm-anchor.keystore -storetype PKCS12 \
  -alias fcm-anchor -keyalg RSA -keysize 4096 -validity 36500 -dname "CN=<you>"

scripts/build.sh      # builds build/FcmAnchor.apk
scripts/install.sh
```

`build.sh` reads `ANDROID_HOME`, `KEYSTORE`, `KEYSTORE_PASS` and `KEY_ALIAS` if they are set. On Linux, set `KEYSTORE_PASS`, because the Keychain lookup only works on macOS.

## Limits

- Only for Xiaomi, Redmi and POCO phones on **China** ROMs. Global and EEA ROMs ship Google services properly and do not need it.
- Normal-priority pushes can still wait for Android's Doze maintenance window, the same as on any Android phone.
- A HyperOS update could rename these settings or change how the freezer works.
- After a factory reset you need ADB again to reinstall.

## Credits

- Based on [PushGuard](https://github.com/waleed46shah/hyperos-cn-notification-fix) by waleed46shah (MIT).
- Freezer internals come from the research in [kingwatam/hyperos-gms-fcm-fix](https://github.com/kingwatam/hyperos-gms-fcm-fix) and [dingwen07/hyperos-fcm-fix](https://github.com/dingwen07/hyperos-fcm-fix).

Not affiliated with Xiaomi or Google. Provided as-is under the [MIT License](LICENSE). It changes system settings; use at your own risk.
