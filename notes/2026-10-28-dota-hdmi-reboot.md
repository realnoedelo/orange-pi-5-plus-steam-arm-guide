# 2026-10-28 — Dota 2 crash, temporary HDMI loss, and reboot

## Observation

During a Dota 2 run through Proton/FEX, the game exited and the projector reported no HDMI signal. The board then came back with a fresh boot; CloverPit was subsequently able to run again.

## Evidence after reconnecting

- HDMI-A-1 was `connected` and exposed 1920x1080 modes.
- Xorg, KWin, SDDM, Steam ARM Big Picture, and Panthor were active.
- Panthor initialized Mali-G610 with CSF firmware successfully.
- The previous boot journal contained no kernel panic, OOM kill, GPU fault, Panthor reset, or HDMI driver failure.
- The journal records a clean `systemd-logind: The system will reboot now` sequence and orderly user-session shutdown. No Dota core dump was available.

## Status

The evidence supports a clean reboot around the incident, but does not identify whether the reboot was user/system initiated or triggered indirectly by the game. A GPU hang is not proven. Keep the Dota reproduction separate from the already verified GPU firmware and HDMI-audio fixes; capture a timestamped kernel journal and game/FEX logs on the next reproduction before changing drivers.
