#!/bin/bash
# Read-only health check. Changes nothing on the phone.
# Paste its output into a "Device report" issue to add your phone to the tested list.
set -uo pipefail
PKG=com.mercuryong.fcmanchor
GMS=com.google.android.gms
a() { adb shell "$@" 2>/dev/null | tr -d '\r'; }
prop() { a getprop "$1"; }

adb get-state >/dev/null 2>&1 || { echo "No phone connected (adb devices)."; exit 1; }

model="$(prop ro.product.marketname)"; [ -n "$model" ] || model="$(prop ro.product.model)"
rom="$(prop ro.mi.os.version.incremental)"; [ -n "$rom" ] || rom="$(prop ro.build.version.incremental)"

echo "== Device"
echo "Model:    $model ($(prop ro.product.model))"
echo "Codename: $(prop ro.product.device)"
echo "ROM:      $rom (region $(prop ro.miui.region))"
echo "Android:  $(prop ro.build.version.release) (API $(prop ro.build.version.sdk))"
echo "Dual Apps (user 999): $(a pm list users | grep -q '{999:' && echo yes || echo no)"

echo
echo "== FCM Anchor"
ver="$(a dumpsys package $PKG | grep -m1 versionName | cut -d= -f2)"
echo "Installed: ${ver:-NO}"
echo "Running:   $(a pidof $PKG >/dev/null && echo yes || echo 'NO (open the app)')"

echo
echo "== Exemption lists"
a settings get system MILLET_NO_RESTRICT_APP | tr ',' '\n' | sed 's/^ *//' | grep -qx $GMS \
  && echo "MILLET_NO_RESTRICT_APP:  Play services on list" || echo "MILLET_NO_RESTRICT_APP:  MISSING"
a settings get system com.miui.game.allowlist | tr '_' '\n' | grep -qx $GMS \
  && echo "com.miui.game.allowlist: Play services on list" || echo "com.miui.game.allowlist: MISSING"

echo
echo "== Play services freezing (Greezer)"
gz="$(a dumpsys greezer)"
if [ -z "$gz" ]; then
  echo "Greezer not present on this ROM"
else
  frozen="$(echo "$gz" | grep -m1 'Frozen processes' | tr -d '[] ' | cut -d: -f2 | tr ',' '\n')"
  for p in $(a pidof $GMS); do
    echo "$frozen" | grep -qx "$p" && echo "pid $p: FROZEN" || echo "pid $p: not frozen"
  done
  uid="$(a dumpsys package $GMS | grep -m1 -oE 'userId=[0-9]+' | cut -d= -f2)"
  echo "Freezes of Play services in Greezer history: $(echo "$gz" | grep -cE "^20.* FZ uid = $uid ")"
fi

echo
echo "== Google push connection"
a dumpsys activity service GcmService | grep -m1 -E "connected=|Is client connected" | sed 's/^ *//' \
  || echo "unknown"
echo
echo "Also check: dial *#*#426#*#* on the phone; FCM should show Connected."
