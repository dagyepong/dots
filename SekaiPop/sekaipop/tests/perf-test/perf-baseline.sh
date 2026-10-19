#!/bin/bash
# Idle / interaction baseline for the running shell. Read-only: it only reads /proc and sysfs.
#
#   sh tests/perf-test/perf-baseline.sh [seconds]        (default 60)
#   PID=1234 sh ...perf-baseline.sh 30                       (pick the process yourself)
#
# Leave the desktop alone while it runs for an IDLE number; open/close panels while it runs
# for an INTERACTION number. Run it once before and once after a change, same conditions
# (same wallpaper, same windows open, same media playing or not), and compare.
#
# What it prints, and what it does NOT tell you:
#   cpu_self    CPU time of quickshell itself (utime+stime), as % of ONE core.
#   cpu_kids    CPU time of the child processes quickshell started AND that have finished
#               (cutime+cstime): the price of every `Process {}` that ran during the window.
#               This is where polling that forks shows up, and it is not in `top`'s %CPU.
#   ctxsw/s     voluntary context switches per second: a proxy for wake-ups.
#   rss/pss     resident and proportional memory of quickshell (smaps_rollup), at the end.
#   gpu_*       SYSTEM-WIDE, not the shell's: the compositor and every other app are in it.
#               Only printed when the driver exposes it (amdgpu gpu_busy_percent, nvidia-smi).
# Not measured here: frame time, GPU memory attributable to the shell, startup time.
# Use SEKAIPOP_PERF=<ms> for the frame-time probe already built into QuickPanel.qml.

secs=${1:-60}
pid=${PID:-$(pgrep -o -x quickshell || pgrep -o -f 'quickshell.* sekaipop')}
[ -n "$pid" ] && [ -r /proc/$pid/stat ] || { echo "quickshell not found (set PID=)"; exit 1; }
hz=$(getconf CLK_TCK)

snap() {  # utime stime cutime cstime voluntary_ctxt_switches
    local s; s=$(cat /proc/$pid/stat) || return 1
    s=${s##*) }; set -- $s     # fields after the comm: state=1 ... utime=12 stime=13 cutime=14 cstime=15
    local ut=${12} st=${13} cu=${14} cs=${15}
    local cx; cx=$(awk '/^voluntary_ctxt_switches/{print $2}' /proc/$pid/status)
    echo "$ut $st $cu $cs $cx"
}

gpu_amd() { for f in /sys/class/drm/card*/device/gpu_busy_percent; do [ -r "$f" ] && echo "$(cat "$f")"; done; }
gpu_nv()  { command -v nvidia-smi >/dev/null && nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1; }

read -r u0 s0 cu0 cs0 x0 <<<"$(snap)"
t0=$(date +%s.%N)
amd_sum=0; amd_n=0; nv_sum=0; nv_n=0
end=$((SECONDS + secs))
while [ $SECONDS -lt $end ]; do
    sleep 1
    a=$(gpu_amd | head -n1); [ -n "$a" ] && { amd_sum=$((amd_sum + a)); amd_n=$((amd_n + 1)); }
    n=$(gpu_nv);             [ -n "$n" ] && { nv_sum=$((nv_sum + n)); nv_n=$((nv_n + 1)); }
done
read -r u1 s1 cu1 cs1 x1 <<<"$(snap)" || { echo "quickshell exited during the run"; exit 1; }
t1=$(date +%s.%N)

awk -v hz="$hz" -v dt="$(echo "$t1 - $t0" | bc -l 2>/dev/null || awk "BEGIN{print $t1-$t0}")" \
    -v self="$(( (u1 - u0) + (s1 - s0) ))" -v kids="$(( (cu1 - cu0) + (cs1 - cs0) ))" -v cx="$((x1 - x0))" 'BEGIN {
    printf "window        %.1f s\n", dt
    printf "cpu_self      %.2f %% of one core\n", 100 * self / hz / dt
    printf "cpu_kids      %.2f %% of one core   (finished child processes)\n", 100 * kids / hz / dt
    printf "ctxsw/s       %.1f\n", cx / dt
}'
awk '/^(Rss|Pss):/{printf "%-13s %.1f MiB\n", tolower(substr($1,1,length($1)-1)), $2/1024}' /proc/$pid/smaps_rollup 2>/dev/null
echo "threads       $(awk '/^Threads/{print $2}' /proc/$pid/status)"
[ $amd_n -gt 0 ] && echo "gpu_amd       $((amd_sum / amd_n)) % busy (system-wide, avg of $amd_n samples)"
[ $nv_n  -gt 0 ] && echo "gpu_nvidia    $((nv_sum / nv_n)) % busy (system-wide, avg of $nv_n samples)"
exit 0
