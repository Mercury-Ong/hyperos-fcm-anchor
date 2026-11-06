#!/bin/bash
# One-off ADB fix: exempts Play services from the HyperOS freezer and reconnects push.
# The greezer flags reset on reboot; re-run if notifications degrade.
# Usage: scripts/hyperos-push-fix.sh          apply
#        scripts/hyperos-push-fix.sh --undo   restore Xiaomi defaults for what this sets
set -uo pipefail
G=com.google.android.gms
a() { adb shell "$@" 2>/dev/null | tr -d '\r'; }

adb get-state >/dev/null 2>&1 || { echo "No phone connected (adb devices)."; exit 1; }
[ "$(a getprop ro.miui.region)" = "CN" ] || echo "Warning: not a China ROM; this fix targets HyperOS CN."

# Android 16+ no longer lets adb shell write Settings.System by default.
a appops set com.android.shell WRITE_SETTINGS allow
trap 'a appops set com.android.shell WRITE_SETTINGS ignore' EXIT

if [ "${1:-}" = "--undo" ]; then
  a settings put system cloud_sleepmode_networkpolicy_enabled on
  a settings delete system cloud_greezer_enable >/dev/null
  a settings delete system cloud_memFreeze_control >/dev/null
  a dumpsys greezer IM GMS enable >/dev/null
  echo "Restored. Exemption-list entries are left alone; uninstall FCM Anchor and Xiaomi drops them on its next rebuild."
  exit 0
fi

# Freezer exemptions (matched by package name, so they cover Dual Apps too)
cur="$(a settings get system MILLET_NO_RESTRICT_APP | tr -d ' ')"; [ "$cur" = "null" ] && cur=""
echo "$cur" | tr ',' '\n' | grep -qx $G || a settings put system MILLET_NO_RESTRICT_APP "${cur:+$cur,}$G"
g="$(a settings get system com.miui.game.allowlist)"; [ "$g" = "null" ] && g=""
echo "$g" | tr '_' '\n' | grep -qx $G || a settings put system com.miui.game.allowlist "${g:+${g}_}$G"

# Sleep-mode network cut and cloud freezer toggles
a settings put system cloud_sleepmode_networkpolicy_enabled off
a settings put system cloud_greezer_enable false
a settings put system cloud_memFreeze_control 0

# Greezer runtime flags (reset on reboot)
a dumpsys greezer IM GMS disable >/dev/null
a dumpsys greezer LM add $G >/dev/null

# Thaw, then reconnect FCM (owner and Dual Apps)
a am broadcast --user 0 -a com.xiaomi.mipush.REFRESH_WHITE_LIST_ACTION -p android --es pkgName $G --ei option -1 >/dev/null
for u in 0 999; do
  a pm list users | grep -q "{$u:" && a am broadcast --user $u -a com.google.android.intent.action.GCM_RECONNECT -p $G >/dev/null
done

a settings get system MILLET_NO_RESTRICT_APP | tr ',' '\n' | sed 's/^ *//' | grep -qx $G \
  && echo "OK: Play services exempt and reconnected" || echo "FAIL: could not write the exemption list"
