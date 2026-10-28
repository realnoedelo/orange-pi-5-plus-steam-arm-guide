# 2026-10-28 — newer Mali firmware and noVNC after reboot

- The board is using the in-tree kernel `panthor` module from Armbian kernel `6.18.44-current-rockchip64`; no out-of-tree/custom kernel GPU module was found under `/lib/modules/.../updates`.
- Mesa is `26.1.6` from Debian trixie-backports and exposes PanVK. The `/opt/fex-rootfs/Ubuntu_24_04-mali` tree is the Steam ARM/FEX userspace graphics provider, not a replacement kernel driver.
- Debian trixie-backports had a newer `firmware-misc-nonfree` (`20260916-1~bpo13+1`) than the installed `20250410-2`. It was installed together with matching `firmware-realtek`, initramfs was regenerated, and the board was rebooted.
- After reboot Panthor initialized with CSF firmware interface `v1.5.0` and firmware git SHA `95a25d71030715381f33105394285e1dcc860a65` (previously interface `v1.1.0`).
- `vnc-greenpow.service` now runs `x11vnc` against the physical HDMI X11 display `:0`; `novnc-greenpow.service` proxies it on port 6080. Both services were active after reboot and the noVNC HTTP endpoint returned 200.
- The debug script default output was moved from `/tmp` to `/home/greenpow/opi-steam-debug-YYYYmmdd-HHMMSS` and flushed each sample, so a hard reboot does not erase the capture directory.

A custom newer kernel driver remains unverified; the current evidence points to testing the newer CSF firmware first, then reproducing Dota with the persistent capture.
