#!/bin/bash
# Installs FCM Anchor on the connected phone and lets it run in the background.
# Usage: scripts/install.sh [path/to/FcmAnchor.apk]
# Needs USB debugging + "Install via USB" (Developer options) on Xiaomi phones.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APK="${1:-$ROOT/build/FcmAnchor.apk}"
PKG=com.mercuryong.fcmanchor
[ -f "$APK" ] || { echo "APK not found: $APK (run scripts/build.sh or download it from Releases)"; exit 1; }

# targetSdk 22 is deliberate (see README); Android 14+ needs this flag to install it.
adb install -r --bypass-low-target-sdk-block "$APK"

adb shell cmd appops set $PKG 10008 allow 2>/dev/null || true   # Xiaomi autostart
adb shell cmd appops set $PKG RUN_ANY_IN_BACKGROUND allow
adb shell cmd appops set $PKG RUN_IN_BACKGROUND allow
adb shell cmd appops set $PKG WRITE_SETTINGS allow
adb shell dumpsys deviceidle whitelist +$PKG >/dev/null
adb shell am set-standby-bucket $PKG active

# Xiaomi may block the first launch behind a prompt; retry once.
adb shell am start -W -n $PKG/.MainActivity >/dev/null
sleep 3
adb shell pidof $PKG >/dev/null || { adb shell am start -W -n $PKG/.MainActivity >/dev/null; sleep 3; }

echo
echo "No-restrict list:"; adb shell settings get system MILLET_NO_RESTRICT_APP
echo "Game allowlist:";   adb shell settings get system com.miui.game.allowlist
echo
echo "FCM Anchor log:"; adb logcat -d -s FcmAnchor | tail -5
echo
echo "Next: Settings > Battery > FCM Anchor > No restrictions."
