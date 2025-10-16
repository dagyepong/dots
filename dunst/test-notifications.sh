#!/bin/bash

# Test different urgency levels with cyberpunk styling

echo "Testing Cyberpunk Dunst Notifications..."

# Low urgency - Cyberpunk Blue
notify-send -u low "󰂯 System Update" "System packages updated successfully
Download speed: 45.2 MB/s"

sleep 2

# Normal urgency - Cyberpunk Cyan
notify-send -u normal "󰊠 Network Connected" "Connected to: CyberNet_WiFi
Signal strength: Excellent
IP: 192.168.1.42" -i network-wireless

sleep 2

# Critical urgency - Cyberpunk Red
notify-send -u critical "󱊟 Battery Critical" "Battery level: 5%
Connect power source immediately
Estimated time remaining: 8 minutes" -i battery-level-20

sleep 2

# With progress bar simulation
notify-send "󰇚 File Transfer" "Downloading: cyberpunk_archive.tar.gz
Progress: 75%" -h int:value:75

sleep 2

# Music notification
notify-send "󰎄 Now Playing" "Artist: Cyber Synth
Track: Neon Dreams
Album: Digital Reality
Duration: 3:45 / 4:20" -i audio-headphones

echo "Notification test complete!"
