#!/usr/bin/env bash
# Launch a Steam app through the already-running native ARM client on the HDMI seat.
set -euo pipefail
APPID="${1:-}"
[ -n "$APPID" ] || { echo "usage: $0 APPID [steam URI suffix]" >&2; exit 2; }
pid="$(pgrep -u greenpow -f './steam -deckard' | head -1 || true)"
[ -n "$pid" ] || { echo "Steam ARM client is not running" >&2; exit 1; }
getenv() { tr '\0' '\n' </proc/"$pid"/environ | sed -n "s/^$1=//p" | head -1; }
export DISPLAY="$(getenv DISPLAY)"
export XAUTHORITY="$(getenv XAUTHORITY)"
export DBUS_SESSION_BUS_ADDRESS="$(getenv DBUS_SESSION_BUS_ADDRESS)"
export XDG_RUNTIME_DIR="/run/user/1000"
[ -n "$DISPLAY" ] || { echo "Steam display environment is unavailable" >&2; exit 1; }
exec runuser -u greenpow -- env DISPLAY="$DISPLAY" XAUTHORITY="$XAUTHORITY" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" /usr/local/bin/steam-arm --open "steam://rungameid/$APPID"
