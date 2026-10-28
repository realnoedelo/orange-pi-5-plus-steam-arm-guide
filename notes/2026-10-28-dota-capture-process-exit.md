# 2026-10-28 — persistent Dota capture: process exit without board reboot

The persistent capture `/home/greenpow/dota-debug-20261028-094536` recorded Dota 2 through FEX/Vulkan. The Dota process was present at roughly 168% CPU and 23% RAM, with temperatures around 65–69°C; HDMI remained connected and the power telemetry nodes reported zero/unavailable input values.

The capture stopped around `09:45:50` and the Dota/FEX process chain then disappeared. The kernel log contains no panic, OOM kill, Panthor fault/reset, HDMI disconnect, or watchdog event. `boot_id` and `who -b` remained unchanged, Xorg/SDDM/KWin/Steam stayed alive, and `coredumpctl` had no entry. This incident is therefore classified as a Dota/FEX/graphics-process exit or display reset, not a confirmed board reboot.

Next work should inspect Dota's `compat_log.txt` and FEX runtime behavior around the exit, and separately reproduce HDMI blanking while checking whether Xorg remains alive. Do not change the kernel driver based on this capture alone.
