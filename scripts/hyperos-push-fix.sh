#!/bin/zsh
# Re-apply HyperOS CN push fix. Run after reboot, app installs, or battery-setting changes.
a(){ adb shell "$@"; }
G=com.google.android.gms
a appops set com.android.shell WRITE_SETTINGS allow
cur=$(a settings get system MILLET_NO_RESTRICT_APP | tr -d ' \r')
echo "$cur" | tr ',' '\n' | grep -qx $G || a settings put system MILLET_NO_RESTRICT_APP "$cur,$G"
g=$(a settings get system com.miui.game.allowlist | tr -d '\r'); [ "$g" = null ] && g=""
echo "$g" | tr '_' '\n' | grep -qx $G || a settings put system com.miui.game.allowlist "${g:+${g}_}$G"
a settings put system cloud_sleepmode_networkpolicy_enabled off
a settings put system cloud_greezer_enable false
a settings put system cloud_memFreeze_control 0
a dumpsys greezer IM GMS disable >/dev/null
a dumpsys greezer LM add $G >/dev/null
a am broadcast --user 0 -a com.xiaomi.mipush.REFRESH_WHITE_LIST_ACTION -p android --es pkgName $G --ei option -1 >/dev/null
a am broadcast --user 0 -a com.google.android.intent.action.GCM_RECONNECT -p $G >/dev/null
a am broadcast --user 999 -a com.google.android.intent.action.GCM_RECONNECT -p $G >/dev/null   # Dual Apps
a appops set com.android.shell WRITE_SETTINGS ignore
a settings get system MILLET_NO_RESTRICT_APP | grep -q $G && echo "OK: Play services exempt" || echo "FAIL: list write"
