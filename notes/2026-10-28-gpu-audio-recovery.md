# 2026-10-28 — GPU firmware and HDMI audio recovery

## Observed before the change

- Armbian 26.8.2 (Debian 13, kernel `6.18.44-current-rockchip64`) was running on the Orange Pi 5 Plus.
- The physical HDMI connector was detected as connected and the Steam ARM Big Picture service was active.
- The kernel `panthor` driver probed the Mali-G610 but failed with `Direct firmware load for arm/mali/arch10.8/mali_csffw.bin failed with error -2`, so the GPU probe failed.
- ALSA exposed `hdmi0`, `hdmi1`, and the onboard Analog card. The connected projector's ELD identified `Xiaomi L1 Pro` on `hdmi0`.
- PipeWire had selected the disconnected `hdmi1` sink as its default after boot, which explains a no-sound symptom even though `hdmi0` was present.

## Changes applied

1. Installed Debian's `firmware-misc-nonfree` package (`20250410-2`), which provides `arm/mali/arch10.8/mali_csffw.bin`.
2. Regenerated the initramfs and rebooted.
3. Set the PipeWire default sink to `alsa_output.platform-hdmi0-sound.stereo-fallback`, set it to 100% and unmuted it.
4. Removed the stale persisted `hdmi1` default from WirePlumber state and restarted the user WirePlumber/PipeWire Pulse services. A timestamped backup of that state file remains beside it on the board.

## Verification after reboot

- `panthor` is loaded and reports `Initialized panthor 1.5.0` with CSF firmware interface `v1.1.0`.
- `vulkaninfo --summary` reports `Mali-G610 MC4`, Mesa `panvk`, and a second `llvmpipe` fallback device.
- `glxinfo -B` reports direct rendering and `Mali-G610 MC4 (Panfrost)`.
- HDMI remains connected and the Steam ARM Big Picture service is active.
- PipeWire now reports `alsa_output.platform-hdmi0-sound.stereo-fallback` as the default sink at 100%.

## Remaining validation

A person at the projector still needs to confirm audible Steam/game audio and launch a real game. The GPU/firmware path is verified from the board; a full game render and physical speaker output are not proven by SSH alone.
