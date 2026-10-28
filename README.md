# Native ARM64 Steam on Orange Pi 5 Plus

A complete bring-up and troubleshooting guide for running Valve's native ARM64 Steam Frame client on an **Orange Pi 5 Plus** with **Rockchip RK3588**, **Mali-G610 MC4**, Debian-based Armbian, KDE Plasma X11, and a headless LAN/VNC workflow.

This guide documents a working configuration reached on:

- Board: Xunlong Orange Pi 5 Plus (`orangepi5-plus`)
- SoC: Rockchip RK3588
- CPU: 8-core ARM64 (Cortex-A55 + Cortex-A76)
- OS: Armbian 26.8.2, Debian 13 (Trixie)
- Kernel: `6.18.44-current-rockchip64`
- GPU kernel driver: `panthor`
- Vulkan: Mesa PanVK 26.1.6 from Debian backports
- Desktop: KDE Plasma on X11
- Remote display: TigerVNC on `:1`, noVNC on port `6080`
- Steam client: Valve native ARM64 Steam Frame client, installed by Steam-ARM 3.1

The client is experimental. It is the same ARM64 client Valve builds for Steam Frame, adapted by the community installer for other ARM64 Linux systems. Valve does not provide ordinary ARM Linux client support.

## What finally fixed the Steam spinner

The visible symptom was:

- Steam accepted the login.
- The window stayed on `Loading user data...` or an endless spinner.
- The logs contained `WaitingForLibraryReady` and:

```text
SteamClient: RefreshPlatformData: failed to load platform app
SteamClient: RefreshSubscriptionMetadata: failed to refresh platform data
SteamClient.System.Network?.StartScanningForNetworks is not a function
```

The root cause was a combination of two ARM client issues:

1. The native Steam client could not load `libnm.so.0`.
2. The Steam UI JavaScript called network methods that are absent from the ARM Steam Frame client. Optional chaining on the `Network` object did not protect calls to missing methods.

The repair was:

1. Install the missing Debian runtime library:

```bash
sudo apt update
sudo apt install -y libnm0
sudo ldconfig
```

2. Patch the Steam UI bundle so missing network methods are skipped safely. The patch is included as [`scripts/patch-steam-network.sh`](scripts/patch-steam-network.sh).

3. Stop every Steam process and start a clean client instance.

4. Use Big Picture once with explicit startup flags, then switch to the desktop interface.

After this sequence, Steam loaded the account, library, friends list, and desktop UI successfully.

## 1. Prepare the graphics stack

Confirm the board, kernel, and GPU:

```bash
cat /etc/armbian-release
uname -a
cat /proc/device-tree/model
lsmod | grep panthor
```

The expected GPU stack is:

```text
panthor
Mali-G610 MC4
panvk
```

Check Vulkan:

```bash
vulkaninfo --summary
```

The important result is:

```text
deviceName  = Mali-G610 MC4
driverName  = panvk
driverInfo  = Mesa 26.1.6-1~bpo13+1
```

`llvmpipe` may also appear as a second CPU fallback device. That does not mean the Mali GPU is unused; select the Mali/PanVK device for graphics applications.

On Debian 13, install the backported Mesa packages if the installed Mesa is too old for PanVK:

```bash
sudo apt update
sudo apt install -y -t trixie-backports \
  mesa-vulkan-drivers libglx-mesa0 mesa-va-drivers mesa-utils vulkan-tools
```

Verify the OpenGL renderer from the graphical session:

```bash
glxinfo -B
```

The renderer must show Panfrost/Mali-G610 rather than llvmpipe.

## 2. Install Steam ARM

The official Armbian module is the supported starting point:

```bash
sudo armbian-config --api module_steam install
```

On ARM64, Armbian installs the client in the desktop user's home directory. It is not a system-wide `/usr/bin/steam` installation.

The community installer used for the RK3588 setup is Steam-ARM 3.1:

<https://github.com/Scrumpper/Steam-ARM/releases>

Install its ARM64 Debian package, then run the setup as the desktop user. Do not run the launcher as root:

```bash
steam-arm --detect
steam-arm --defaults
```

The installer provides the RK3588-specific pieces used by this configuration, including:

- FEX rootfs and ARM64 Steam client setup
- PanVK/Vulkan compatibility handling
- patched GLX handling for threaded CEF/OpenGL use
- Vulkan feature spoofing for the emulated game path
- controller access rules
- Steam Frame/ARM64 launcher and desktop entries

The client data directory is:

```text
/home/<user>/.local/share/steam-arm/.local/share/Steam
```

Replace `<user>` with the graphical desktop account. In this setup it was `greenpow`.

## 3. Install the missing NetworkManager library

Before launching Steam, check the native client dependencies:

```bash
STEAM_ROOT="$HOME/.local/share/steam-arm/.local/share/Steam"
ldd "$STEAM_ROOT/steamrtarm64/steamclient.so" | grep -E 'not found|libnm'
```

If the result contains:

```text
libnm.so.0 => not found
```

install the library:

```bash
sudo apt update
sudo apt install -y libnm0
sudo ldconfig
```

Recheck:

```bash
ldd "$STEAM_ROOT/steamrtarm64/steamclient.so" | grep -E 'not found|libnm'
```

The expected result is a real path such as:

```text
libnm.so.0 => /lib/aarch64-linux-gnu/libnm.so.0
```

Installing `libnm0` does not require enabling or switching the NetworkManager service. It only supplies the missing native library.

## 4. Apply the Steam UI network shim

The failing Steam UI bundle is usually:

```text
$STEAM_ROOT/steamui/sp.js
```

Create a backup first. The included script refuses to patch an unexpected client layout and keeps a backup beside the file:

```bash
bash scripts/patch-steam-network.sh
```

The script changes three calls:

```javascript
He && typeof SteamClient.System.Network?.RegisterForDeviceChanges === "function" &&
  SteamClient.System.Network.RegisterForDeviceChanges(this.OnNetworkDevicesChanged)
```

```javascript
SteamClient.System.Network?.StartScanningForNetworks?.()?.then(l.rA)
SteamClient.System.Network?.StopScanningForNetworks?.()?.then(l.rA)
```

The original client used only:

```javascript
SteamClient.System.Network?.StartScanningForNetworks().then(...)
```

That checks whether `Network` exists, but not whether the method exists. The ARM client exposes neither method, so the UI threw a TypeError.

The patch is a workaround for the current client build. Steam self-updates can replace `sp.js`; if that happens, run the script again and restart Steam.

## 5. Start Big Picture for the first clean test

Always stop a running client before changing startup flags. Steam ignores many flags when another instance is already running.

```bash
steam-arm --shutdown
pkill -TERM -u "$USER" -f 'steamwebhelper|steam -deckard|steamrtarm64/steam' || true
sleep 3
pkill -KILL -u "$USER" -f 'steamwebhelper|steam -deckard|steamrtarm64/steam' || true
```

Start Big Picture with explicit debug/window flags and CEF compositing disabled:

```bash
STEAM_ARM_UI=bigpicture \
steam-arm --bigpicture \
  -dev \
  -windowed \
  -cef-disable-gpu \
  -cef-disable-gpu-compositing
```

The resulting process should contain:

```text
-gamepadui
-dev
-windowed
-cef-disable-gpu
-cef-disable-gpu-compositing
```

These flags affect the Steam UI/CEF layer. They do not disable PanVK for ARMSX2 or the game graphics path.

Log in once. A successful login is shown by:

```text
Received logon success response
client login returned 1 (Success)
```

A working client eventually exposes the library and account UI instead of remaining on the spinner.

## 6. Switch to the normal desktop interface

After the first successful Big Picture login, switch to the ordinary Steam window:

```bash
steam-arm --desktop
```

The desktop process should no longer contain `-gamepadui`. The ARM client may still contain `-deckard -steamos3`; those flags select the ARM/Steam Frame client backend, while `-gamepadui` selects the Big Picture interface.

The successful desktop result is a normal Steam window showing Store/Library/Friends, account status, and the user's library.

### Recovery after logging out of KDE or reconnecting VNC

A graphical logout can leave one or more `steam-arm --desktop` shell wrappers behind while the actual Steam client has already exited. Starting the desktop icon repeatedly then leaves several wrappers sleeping and no Steam window. Clean the stale launchers before starting one new instance:

```bash
pkill -TERM -u "$USER" -f "/usr/local/bin/steam-arm" || true
sleep 3
pkill -KILL -u "$USER" -f "/usr/local/bin/steam-arm" || true
pkill -TERM -u "$USER" -f "steamwebhelper|steam -deckard|steamrtarm64/steam" || true
sleep 3

DISPLAY=:1 \
XAUTHORITY="$HOME/.Xauthority" \
XDG_RUNTIME_DIR="/run/user/$(id -u)" \
DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus" \
HOME="$HOME" \
steam-arm --desktop -dev -windowed -cef-disable-gpu -cef-disable-gpu-compositing
```

Verify that there is exactly one main client:

```bash
pgrep -a -u "$USER" -f "steam -deckard|steamwebhelper"
```

The login log should end with:

```text
SetLoginState: Success - OK
```

Do not start several desktop icons at once. The launcher deliberately waits while another start is in progress.

## 7. Run Steam remotely without a monitor

The board can run a KDE X11 session and expose it through TigerVNC/noVNC.

Check the services:

```bash
systemctl status vnc-greenpow.service
systemctl status novnc-greenpow.service
```

The noVNC page is:

```text
http://<board-ip>:6080/vnc.html
```

The TigerVNC display is `:1` and uses the configured virtual display geometry. RandR modes are available through the VNC X server; do not add an unsupported `-randr` option to TigerVNC's `vncserver` wrapper.

Launch GUI programs with the graphical user's environment:

```bash
DISPLAY=:1 \
XAUTHORITY="$HOME/.Xauthority" \
XDG_RUNTIME_DIR="/run/user/$(id -u)" \
DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus" \
steam-arm --desktop
```

Running `steam` as root is expected to fail with:

```text
steam: command not found
```

The ARM client is per-user and intentionally must be run as the desktop user. Use `steam-arm`, not a root shell's `steam` command.

## 8. LAN versus Wi-Fi in Big Picture

The board uses wired LAN. Steam Frame's Internet settings page is written for SteamOS hardware and may show:

```text
Wi-Fi disabled
No other networks found
```

That refers to the board's Wi-Fi adapter. It does not mean Ethernet is offline. Successful Steam login, friends status, store/library loading, and a direct HTTPS test prove the LAN path is working.

Check the actual LAN path outside Steam:

```bash
curl -I --max-time 10 https://store.steampowered.com
ip route
```

DNS used in the working setup:

```text
1.1.1.1
8.8.8.8
```

Configure DNS through the active network manager rather than editing the generated `/etc/resolv.conf` stub directly.

## 9. Diagnostics

### Steam process state

```bash
pgrep -a -u "$USER" -f 'steam -deckard|steamwebhelper'
```

### Login state

```bash
tail -n 80 "$STEAM_ROOT/logs/steamui_login.txt"
```

Healthy login lines include:

```text
Received logon success response
Resolve login request: OK - Success
client login returned 1 (Success)
```

### CEF/UI errors

```bash
tail -n 120 "$STEAM_ROOT/logs/webhelper_js.txt"
grep -E 'ERROR|WARNING|TypeError|RefreshPlatformData|Network' \
  "$STEAM_ROOT/logs/webhelper_js.txt"
```

Old errors can remain in the same log. Compare timestamps and inspect only lines from the latest launch.

### Verify the network shim is still present

```bash
grep -o 'RegisterForDeviceChanges' "$STEAM_ROOT/steamui/sp.js" | head
grep -o 'StartScanningForNetworks' "$STEAM_ROOT/steamui/sp.js" | head
```

If a fresh `StartScanningForNetworks is not a function` error returns after a Steam update, apply the patch again.

### Verify GPU use

```bash
vulkaninfo --summary | grep -E 'deviceName|driverName|driverInfo'
```

For ARMSX2/PS2, the working output showed Vulkan/PanVK, Mali-G610, and stable 60+ FPS in the tested scene. Steam UI CEF compositing is a separate layer and may be disabled for stability.

## 10. Common mistakes and failed approaches

### Running Steam as root

The client is installed for the graphical user. Root does not have the user's Steam files, DBus session, Xauthority, or account data. Run `steam-arm` as the desktop user.

### Using `-deckard` as a permanent menu command

Armbian uses `steam -deckard -exitsteam` for a one-time bootstrap. The normal menu entry should not permanently force the bootstrap command. Steam-ARM intentionally uses the Steam Frame ARM64 backend and provides `--desktop`/`--bigpicture` for the interface choice.

### Assuming the Internet page proves the board is offline

The Big Picture Internet page shows Wi-Fi state. This board is on Ethernet, so Wi-Fi being disabled is expected.

### Deleting the Steam directory repeatedly

Deleting the client cache does not fix a missing native library or missing IPC binding. It also causes repeated downloads and repeated authentication. Preserve the client, library, games, and account data while testing.

### Replacing TigerVNC immediately

The existing TigerVNC/noVNC setup provides an X11 display and RandR modes. An unsupported `-randr` argument caused a separate VNC startup failure; it was not needed for Steam.

### Treating `RefreshPlatformData` as a missing folder

The message refers to Steam Frame platform integration. It is generated by the native client and is not fixed by creating arbitrary KDE or Steam library directories. The actionable missing host dependency in this setup was `libnm.so.0`; the JavaScript network shim handled the missing UI methods.

## 11. Files and services from the working setup

Important paths:

```text
/home/<user>/.local/share/steam-arm/
/home/<user>/.local/share/steam-arm/.local/share/Steam/steamrtarm64/steam
/home/<user>/.local/share/steam-arm/.local/share/Steam/steamui/sp.js
/home/<user>/.local/share/steam-arm/.local/share/Steam/steamui/sp.js.pre-network-shim
```

Services used for the headless graphical workflow:

```text
vnc-greenpow.service
novnc-greenpow.service
qbittorrent-greenpow.service
```

Do not publish or commit:

- Steam credentials or authentication tokens
- root or desktop passwords
- SSH private keys
- PS2 BIOS dumps
- copyrighted ROMs or game images
- private LAN topology if the guide is public

## References

- Armbian Steam documentation: <https://docs.armbian.com/software/steam/>
- Steam-ARM installer: <https://github.com/Scrumpper/Steam-ARM>
- Steam-ARM RK3588 discussion: <https://forum.armbian.com/topic/62259-native-arm64-steam-client-installer-built-on-rk3588-board-using-the-arm64-steam-frames-client/>
- Valve Steam-for-Linux issue #13493: <https://github.com/ValveSoftware/steam-for-linux/issues/13493>
- ARM troubleshooting showing the missing `libnm.so.0` dependency: <https://github.com/thatwhichisdev/steam-asahi>
- Steam Frame product information: <https://store.steampowered.com/hardware/steamframe>
