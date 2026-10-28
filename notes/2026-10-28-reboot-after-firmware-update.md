# 2026-10-28 — reboot attribution after firmware update

The board was rebooted after installing the newer backports firmware. The persistent journal records an orderly `systemd-logind: The system will reboot now` sequence at `09:39:19`, followed by normal shutdown of Plasma, Steam, SDDM, networking, and PipeWire. There is no kernel panic, OOM kill, Panthor fault, or HDMI reset in that boot.

No Dota process log or persistent debug capture was present for this boot, so this reboot cannot be attributed to Dota. The earlier live capture was under `/tmp` and was lost across reboot; `/usr/local/bin/opi-steam-debug` now writes to `/home/greenpow/opi-steam-debug-<timestamp>` and flushes each sample. The next reproduction must use the updated script before launching AppID 570.
