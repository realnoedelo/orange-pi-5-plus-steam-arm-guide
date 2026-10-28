# 2026-10-28 — FlatOut freeze escalated to system hard lock

After reproducing the FlatOut 2 3D freeze, the board stopped responding to SSH, ping, VNC, and gamepad input. A physical reboot was required. The next boot had a new journal boot ID and initialized HDMI and Panthor normally with CSF firmware interface `v1.5.0`.

The prior boot had no orderly shutdown, kernel panic, OOM report, watchdog message, Panthor fault, or HDMI reset before the lock. The earlier GDB backtrace showed FlatOut's WSI swapchain, disk, and DXVK threads waiting in `libvulkan_panfrost.so`. This is now classified as a system-level GPU/Vulkan deadlock capable of locking the board, not merely a frozen game window.

Do not launch FlatOut again with the same Vulkan path until a controlled comparison is prepared (Proton 11 ARM64 and/or a verified `STEAM_ARM_VK_SPOOF_DISABLE=1` environment). Keep the kernel and firmware unchanged for that comparison.
