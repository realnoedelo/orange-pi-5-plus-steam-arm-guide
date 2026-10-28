#!/usr/bin/env bash
set -euo pipefail

STEAM_ROOT="${STEAM_ROOT:-$HOME/.local/share/steam-arm/.local/share/Steam}"
UI="$STEAM_ROOT/steamui/sp.js"
BACKUP="$STEAM_ROOT/steamui/sp.js.pre-network-shim"

if [[ ! -f "$UI" ]]; then
  echo "Steam UI bundle not found: $UI" >&2
  exit 1
fi

python3 - "$UI" "$BACKUP" <<'PY'
from pathlib import Path
import sys

ui = Path(sys.argv[1])
backup = Path(sys.argv[2])
s = ui.read_text()

old_register = 'He&&SteamClient.System.Network.RegisterForDeviceChanges(this.OnNetworkDevicesChanged)'
new_register = 'He&&typeof SteamClient.System.Network?.RegisterForDeviceChanges==="function"&&SteamClient.System.Network.RegisterForDeviceChanges(this.OnNetworkDevicesChanged)'
old_start = 'SteamClient.System.Network?.StartScanningForNetworks().then(l.rA)'
new_start = 'SteamClient.System.Network?.StartScanningForNetworks?.()?.then(l.rA)'
old_stop = 'SteamClient.System.Network?.StopScanningForNetworks().then(l.rA)'
new_stop = 'SteamClient.System.Network?.StopScanningForNetworks?.()?.then(l.rA)'

if 'typeof SteamClient.System.Network?.RegisterForDeviceChanges' in s:
    print('already patched')
    raise SystemExit(0)

for old in (old_register, old_start, old_stop):
    if old not in s:
        raise SystemExit(f'expected Steam UI pattern not found: {old}')

if not backup.exists():
    backup.write_text(s)

s = s.replace(old_register, new_register, 1)
s = s.replace(old_start, new_start, 1)
s = s.replace(old_stop, new_stop, 1)
ui.write_text(s)
print(f'patched: {ui}')
print(f'backup:  {backup}')
PY
