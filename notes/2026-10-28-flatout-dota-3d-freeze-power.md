# 2026-10-28 — FlatOut and Dota freeze at 3D initialization

FlatOut 2 and Dota 2 both reproduced a freeze when entering the 3D/Vulkan path. During the FlatOut check, `FlatOut2.exe` was alive and using CPU, HDMI was connected, and temperatures were approximately 60–62°C. No Panthor, DRM, OOM, watchdog, or GPU fault appeared in the kernel journal.

Power telemetry showed `vcc5v0_sys=5000mV` and `vbus5v0_typec=5000mV`, with no voltage drop. The board exposes no usable input current/Power-Watt reading (`tcpm-source-psy` and hwmon current values are zero), so a 20W delivery cannot be proven from software.

Both games run through Steam ARM/FEX and Vulkan with the active `VK_LAYER_STEAM_ARM_feature_spoof` (`vk-spoof`). The layer reports missing Vulkan features as supported and strips them during device creation. This is now the leading shared 3D-freeze hypothesis. Next controlled reproduction should disable `STEAM_ARM_VK_SPOOF` for one title at a time and compare whether 3D initialization completes; do not change the kernel driver yet.
