#!/bin/bash
# Builds and signs FcmAnchor.apk with plain SDK tools (aapt2, javac, d8, zipalign, apksigner).
# Env: ANDROID_HOME (default ~/Library/Android/sdk), KEYSTORE (default ~/keys/fcm-anchor.keystore),
#      KEYSTORE_PASS (default: macOS Keychain item "fcm-anchor-keystore"), KEY_ALIAS (default fcm-anchor).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
BT="$(ls -d "$SDK"/build-tools/*/ | sort -V | tail -1)"
PLAT="$(ls -d "$SDK"/platforms/android-*/ | sort -V | tail -1)android.jar"
[ -f "$PLAT" ] || { echo "Android SDK not found in $SDK"; exit 1; }

KEYSTORE="${KEYSTORE:-$HOME/keys/fcm-anchor.keystore}"
KEY_ALIAS="${KEY_ALIAS:-fcm-anchor}"
[ -f "$KEYSTORE" ] || { echo "Keystore not found: $KEYSTORE (see README)"; exit 1; }
if [ -z "${KEYSTORE_PASS:-}" ]; then
  KEYSTORE_PASS="$(security find-generic-password -s fcm-anchor-keystore -w 2>/dev/null)" \
    || { echo "Set KEYSTORE_PASS or add Keychain item 'fcm-anchor-keystore'"; exit 1; }
fi
export KEYSTORE_PASS

VERSION_NAME="${VERSION_NAME:-1.0.0}"
VERSION_CODE="${VERSION_CODE:-1}"

rm -rf build && mkdir -p build/classes

echo "[1/5] Manifest"
"$BT/aapt2" link -o build/base.apk --manifest app/AndroidManifest.xml -I "$PLAT" \
  --min-sdk-version 26 --target-sdk-version 22 \
  --version-code "$VERSION_CODE" --version-name "$VERSION_NAME"

echo "[2/5] Compile"
javac --release 17 -Xlint:-options -classpath "$PLAT" -d build/classes \
  app/src/com/mercuryong/fcmanchor/*.java

echo "[3/5] Dex"
"$BT/d8" --release --min-api 26 --lib "$PLAT" --output build build/classes/com/mercuryong/fcmanchor/*.class
(cd build && zip -q base.apk classes.dex)

echo "[4/5] Align"
"$BT/zipalign" -f -p 4 build/base.apk build/aligned.apk

echo "[5/5] Sign"
"$BT/apksigner" sign --ks "$KEYSTORE" --ks-key-alias "$KEY_ALIAS" \
  --ks-pass env:KEYSTORE_PASS --key-pass env:KEYSTORE_PASS \
  --out build/FcmAnchor.apk build/aligned.apk 2>/dev/null
"$BT/apksigner" verify build/FcmAnchor.apk 2>/dev/null
rm -f build/FcmAnchor.apk.idsig
echo
echo "Built: $ROOT/build/FcmAnchor.apk"
