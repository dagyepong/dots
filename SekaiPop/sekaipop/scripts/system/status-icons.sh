#!/bin/sh

# One quick look at Wi-Fi, Ethernet and Bluetooth for the bar's status pill
# (services/StatusIconsService.qml). Prints key=value lines; a tool that is
# missing (or has no adapter) just leaves its value empty.
#
#   wifi    "enabled" / "disabled"    the Wi-Fi radio (empty: no NetworkManager)
#   ssid    the Wi-Fi connection that is up, "" when none
#   eth     the wired connection that is up, "" when none
#   bt      "yes" / "no"              the Bluetooth adapter's power (empty: no adapter)
#   btdev   the first connected Bluetooth device, "" when none
#
# Nothing here scans: `nmcli dev` only reads NetworkManager's state, so it is
# cheap to run every few seconds.
#
# This runs on a timer for the whole life of the shell, so it spawns as few
# processes as it can: one nmcli per question, one bluetoothctl per question,
# and the picking of the first matching line is done with the shell's own
# builtins (it used to be a sed | head pipeline per value, ~10 extra forks).

w=$(timeout 2 nmcli -t radio wifi 2>/dev/null)
dev=$(timeout 2 nmcli -t -e no -f TYPE,STATE,CONNECTION dev 2>/dev/null)
bshow=$(timeout 2 bluetoothctl show 2>/dev/null)
bdevs=$(timeout 2 bluetoothctl devices Connected 2>/dev/null)

s=; e=; b=; d=
sf=0; ef=0

# First "wifi:connected:<name>" and first "ethernet:connected:<name>".
while IFS= read -r line; do
    case $line in
        wifi:connected:*)
            if [ "$sf" = 0 ]; then s=${line#wifi:connected:}; sf=1; fi ;;
        ethernet:connected:*)
            if [ "$ef" = 0 ]; then e=${line#ethernet:connected:}; ef=1; fi ;;
    esac
    [ "$sf" = 1 ] && [ "$ef" = 1 ] && break
done <<EOT
$dev
EOT

# First "Powered: yes|no" (the line is indented).
while IFS= read -r line; do
    t=${line#"${line%%[![:space:]]*}"}
    case $t in
        "Powered: "*) b=${t#"Powered: "}; break ;;
    esac
done <<EOT
$bshow
EOT

# First "Device <mac> <name>" that has a name.
while IFS= read -r line; do
    case $line in
        "Device "*)
            rest=${line#"Device "}
            case $rest in
                *" "*) d=${rest#* }; break ;;
            esac ;;
    esac
done <<EOT
$bdevs
EOT

printf 'wifi=%s\nssid=%s\neth=%s\nbt=%s\nbtdev=%s\n' "$w" "$s" "$e" "$b" "$d"
