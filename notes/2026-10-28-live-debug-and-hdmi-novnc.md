# 2026-10-28 — Live debug capture and noVNC HDMI mirror

## Live debug capture

The board has `/usr/local/bin/opi-steam-debug`, copied from [`scripts/opi-steam-debug.sh`](../scripts/opi-steam-debug.sh). Run it as root in one SSH terminal:

```sh
sudo /usr/local/bin/opi-steam-debug
```

It prints one sample per second and writes a private capture directory under `/tmp/opi-steam-debug-YYYYmmdd-HHMMSS/`. Stop with `Ctrl-C`; send the directory contents when convenient. `kernel.log`, `steam.log`, and `compat.log` are captured alongside `live.tsv` and `metadata.txt`. `--duration 600` limits a run to ten minutes.

## Repro launch

The board has `/usr/local/bin/opi-steam-run`, copied from [`scripts/opi-steam-run.sh`](../scripts/opi-steam-run.sh). In a second SSH terminal, launch Dota 2 through the existing HDMI Steam session with:

```sh
sudo /usr/local/bin/opi-steam-run 570
```

This uses Steam's existing `DISPLAY`, Xauthority, and DBus session, so it does not start a second Steam client.

## noVNC

The old TigerVNC `:1` service created a separate KDE desktop. It was replaced with `x11vnc` attached to the physical HDMI X11 display `:0`; the existing noVNC gateway remains on port 6080 and forwards to VNC port 5901. The projector and noVNC now show/control the same Steam session. The local URL is `http://<board-ip>:6080/vnc.html?autoconnect=1&resize=scale`.

The x11vnc service waits for the SDDM Xauthority file and restarts with the HDMI display. A copy of the former TigerVNC unit is retained on the board as `/etc/systemd/system/vnc-greenpow.service.tigervnc-20261028`.
