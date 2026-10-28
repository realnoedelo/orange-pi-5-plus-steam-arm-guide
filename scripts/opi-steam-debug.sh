#!/usr/bin/env bash
# Live Orange Pi / Steam ARM diagnostic capture.
# Run as root on the board. Stop with Ctrl-C; the capture directory is printed.
set -u

DURATION=0
OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --duration) DURATION="${2:-0}"; shift 2 ;;
    --out) OUT="${2:-}"; shift 2 ;;
    -h|--help)
      cat <<USAGE
Usage: sudo $0 [--duration SECONDS] [--out DIRECTORY]

The default duration is unlimited; stop with Ctrl-C. The output directory contains:
  live.tsv       one hardware/process sample per second (also printed to stdout)
  kernel.log     live kernel journal
  steam.log      Steam ARM launcher log (if present)
  compat.log     Proton/FEX compatibility log (if present)
  metadata.txt   immutable command/system snapshot
USAGE
      exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

[ "$(id -u)" -eq 0 ] || { echo "run as root: sudo $0" >&2; exit 1; }
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${OUT:-/tmp/opi-steam-debug-$STAMP}"
mkdir -p "$OUT"

# Keep all files private by default; logs can contain local paths and process arguments.
umask 077
exec > >(tee "$OUT/live.tsv") 2>&1

cleanup() {
  trap - INT TERM EXIT
  for p in ${KPID:-} ${SPID:-} ${CPID:-}; do kill "$p" 2>/dev/null || true; done
  echo "CAPTURE_DIR=$OUT"
}
trap cleanup INT TERM EXIT

{
  echo "started=$(date -Is)"
  echo "kernel=$(uname -a)"
  echo "os=$(tr '\n' ' ' </etc/os-release)"
  echo "cmdline=$(cat /proc/cmdline)"
  echo "power_supplies:"
  find /sys/class/power_supply -maxdepth 2 -type f -print 2>/dev/null | sort
  echo "hwmon:"
  for d in /sys/class/hwmon/hwmon*; do
    [ -d "$d" ] || continue
    printf '%s name=%s\n' "$d" "$(cat "$d/name" 2>/dev/null || true)"
  done
  echo "drm:"
  for f in /sys/class/drm/*/status; do printf '%s=' "$f"; cat "$f" 2>/dev/null || true; done
  echo "gpu_devfreq:"
  find /sys/class/devfreq -maxdepth 2 -type f \( -name cur_freq -o -name busy_time -o -name total_time -o -name governor \) -print 2>/dev/null | sort
  echo "packages:"
  dpkg-query -W -f='${Package} ${Version}\n' firmware-misc-nonfree linux-image-current-rockchip64 mesa-vulkan-drivers steam-arm-setup 2>/dev/null || true
} >"$OUT/metadata.txt"

# Follow independent logs while the game is running.
journalctl -kf -o short-iso >"$OUT/kernel.log" 2>&1 & KPID=$!
STEAM_LOG=/home/greenpow/.local/share/steam-arm/steam-arm.log
COMPAT_LOG=/home/greenpow/.local/share/steam-arm/.local/share/Steam/logs/compat_log.txt
[ -f "$STEAM_LOG" ] && tail -F "$STEAM_LOG" >"$OUT/steam.log" 2>&1 & SPID=$!
[ -f "$COMPAT_LOG" ] && tail -F "$COMPAT_LOG" >"$OUT/compat.log" 2>&1 & CPID=$!

START="$(date +%s)"
echo "capture=$OUT started=$(date -Is) duration=${DURATION}s (Ctrl-C to stop)"
while :; do
  NOW="$(date -Is)"
  ELAPSED=$(( $(date +%s) - START ))
  printf '\n[%s] elapsed=%ss\n' "$NOW" "$ELAPSED"
  printf 'uptime='; awk '{print $1}' /proc/uptime
  printf 'memory='; awk '/MemTotal|MemAvailable|SwapFree/ {printf "%s=%sKB ", $1, $2} END {print ""}' /proc/meminfo
  printf 'hdmi='; for f in /sys/class/drm/*/status; do printf '%s:%s ' "$(basename "$(dirname "$f")")" "$(cat "$f" 2>/dev/null || echo '?')"; done; echo
  printf 'thermal='; for f in /sys/class/thermal/thermal_zone*/temp; do printf '%s=%sC ' "$(basename "$(dirname "$f")")" "$(awk '{printf "%.1f", $1/1000}' "$f" 2>/dev/null)"; done; echo
  printf 'freq='; for f in /sys/devices/system/cpu/cpufreq/policy*/scaling_cur_freq; do printf '%s=%sMHz ' "$(basename "$(dirname "$f")")" "$(awk '{printf "%.0f", $1/1000}' "$f" 2>/dev/null)"; done; echo
  printf 'power='; for f in /sys/class/power_supply/*/{online,status,voltage_now,current_now,power_now}; do [ -f "$f" ] && printf '%s=%s ' "$f" "$(cat "$f" 2>/dev/null)"; done; for f in /sys/class/hwmon/hwmon*/{in*_input,curr*_input,power*_input}; do [ -f "$f" ] && printf '%s=%s ' "$f" "$(cat "$f" 2>/dev/null)"; done; echo
  printf 'gpu_devfreq='; for f in /sys/class/devfreq/*/{cur_freq,busy_time,total_time,governor}; do [ -f "$f" ] && printf '%s=%s ' "$f" "$(cat "$f" 2>/dev/null)"; done; echo
  echo 'processes:'
  ps -eo pid,ppid,stat,pcpu,pmem,etime,args --sort=-pcpu | egrep -i 'CloverPit|dota|steam|proton|wine|fex|pressure-vessel|gamescope|Xorg|kwin' | head -35 || true
  if [ "$DURATION" -gt 0 ] 2>/dev/null && [ "$ELAPSED" -ge "$DURATION" ]; then break; fi
  sleep 1
done
