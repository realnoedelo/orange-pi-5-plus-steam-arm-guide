# 2026-10-28 — FlatOut Vulkan freeze backtrace

FlatOut 2 was reproduced with Proton Experimental ARM64 and then inspected without killing the desktop session. The real Windows process (`FlatOut2.exe`) had 34 threads and about 704 MiB RSS. A GDB all-thread backtrace showed:

- the WSI swapchain threads blocked in `libvulkan_panfrost.so` condition waits;
- `FlatOut:disk$0` and `FlatOut:disk$1` also blocked in `libvulkan_panfrost.so`;
- DXVK submit/queue and shader threads waiting in the same Vulkan/Wine path;
- no kernel Panthor fault, reset, HDMI error, or thermal event.

This is a Vulkan/PanVK swapchain or submission deadlock, not a board-wide power reset. The first attempt to disable `vk-spoof` via a per-title `titles.conf` did not reach the game environment (the running process had no `STEAM_ARM_VK_SPOOF_DISABLE`), so that hypothesis remains untested. The temporary title config was removed. Next controlled comparison: run FlatOut with Proton 11 ARM64 or pass the spoof-disable environment through the actual Steam service environment, one variable at a time.
