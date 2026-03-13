#!/bin/bash
# Get the primary active connection from NetworkManager
connection=$(nmcli -t -f TYPE,NAME connection show --active | head -n1)

if [ -n "$connection" ]; then
    type=$(echo "$connection" | cut -d: -f1)
    name=$(echo "$connection" | cut -d: -f2)

    case "$type" in
        "802-11-wireless")
            echo " $name"   # Wi‑Fi icon + SSID
            ;;
        "802-3-ethernet")
            echo "󰤯 Ethernet" # Ethernet icon
            ;;
        *)
            echo "󰤭 $type"    # Fallback (e.g., VPN, bridge)
            ;;
    esac
else
    echo "󰤭 Offline"
fi
