#!/bin/sh
# Prints the system status, one line per entry (read by SysStats.qml)
head -n1 /proc/stat
awk '/^MemTotal:/{print "memtotal", $2} /^MemAvailable:/{print "memavail", $2}' /proc/meminfo
awk 'NR>2 { gsub(":", " ", $0); if ($1 != "lo") { rx += $2; tx += $10 } } END { print "net", rx, tx }' /proc/net/dev
df -B1 --output=size,used / | tail -n1 | awk '{print "disk", $1, $2}'
