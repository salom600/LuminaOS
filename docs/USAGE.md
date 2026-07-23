# USAGE — LuminaOS end-user guide

## 1. Downloading the ISO

1. Go to <https://github.com/salom600/LuminaOS/releases>
2. Download the latest `lumina-os-<version>-x86_64.iso` and its `.sha256`
3. (Optional) Verify: `sha256sum -c lumina-os-*.sha256`

## 2. Flashing to USB

### On Windows
Use **Rufus** (<https://rufus.ie>):
- Select the ISO
- Partition scheme: **GPT** for UEFI, **MBR** for legacy BIOS
- Click **Start**
- Use **DD mode** if Rufus asks

### On macOS / Linux
```bash
# Find your USB device (careful! this will erase it)
lsblk

# Flash (replace sdX with your USB device, NOT a partition)
sudo dd if=lumina-os-*.iso of=/dev/sdX bs=4M conv=fsync status=progress
sync
```

Or use **balenaEtcher** (<https://etcher.balena.io>) — cross-platform GUI.

## 3. Booting the live session

1. Plug the USB into the target machine
2. Power on, press the boot menu key (F12 / F8 / F11 / Esc — varies by vendor)
3. Select the USB device
4. At the LuminaOS boot menu, press Enter on the default entry
5. After ~15 s you'll be at the LuminaOS desktop

The live session user is `lumina` with password `lumina`. You don't need to log in — the live session auto-logs in.

## 4. Installing LuminaOS

1. Double-click **Install LuminaOS** on the desktop
2. The installer (Calamares) opens
3. Choose:
   - **Language** (English, Arabic, French, Spanish, German, …)
   - **Timezone**
   - **Keyboard layout**
   - **Disk** (whole disk or alongside existing OS)
   - **User** — username, password, computer name
   - **Optional** — full-disk encryption (LUKS)
4. Click **Install**
5. Wait ~5 minutes
6. Click **Restart Now**
7. Remove the USB when prompted

## 5. First boot

After install, on first boot:
- Login screen appears (you set the password during install)
- Hyprland starts automatically
- A "Welcome" window offers:
  - Connect to Wi-Fi
  - Install additional software
  - Set wallpaper
  - Read the short Getting Started guide

## 6. Daily usage — keyboard shortcuts

| Shortcut | Action |
|---|---|
| `Super` | Open app launcher (Wofi) |
| `Super` + `Enter` | Open terminal (kitty) |
| `Super` + `E` | Open file manager (Thunar) |
| `Super` + `B` | Open browser (Firefox) |
| `Super` + `S` | Open Lumina Store |
| `Super` + `Q` | Close focused window |
| `Super` + `D` | Show desktop |
| `Super` + `1..9` | Switch to workspace N |
| `Super` + `Shift` + `1..9` | Move window to workspace N |
| `Alt` + `Tab` | Switch windows |
| `Super` + `Tab` | Switch workspaces (visual) |
| `Super` + `Arrow` | Tile window (left/right/up/down) |
| `Super` + `Mouse` | Move window |
| `Super` + `Right-click` | Resize window |
| `Ctrl` + `Shift` + `Esc` | Task manager (htop) |
| `PrtScn` | Screenshot tool |
| `Super` + `L` | Lock screen |

## 7. Installing apps

### From Lumina Store (recommended)
1. Press `Super` + `S` (or click the store icon in the taskbar)
2. Browse or search
3. Click **Install** next to an app
4. Enter your password when prompted

### From terminal
```bash
# System packages (Alpine)
sudo apk add firefox

# Flatpak apps (Flathub)
flatpak install flathub com.spotify.Client

# Update everything
sudo apk upgrade
flatpak update
```

## 8. Connecting to Wi-Fi

1. Click the network icon in the taskbar (bottom-right)
2. Select your Wi-Fi network
3. Enter password
4. Connected — NetworkManager remembers it

For wired networks, just plug in the cable. DHCP is automatic.

## 9. Changing wallpaper & theme

1. Right-click on the desktop → **Personalize**
2. Pick a wallpaper from the gallery, or browse for your own
3. Toggle **Light / Dark** mode
4. Choose accent color (default: Windows-blue #0078D4)

## 10. Installing GPU drivers

LuminaOS ships with **Mesa** (AMD + Intel) out of the box — they "just work".

For **Nvidia**:
1. Open Lumina Store
2. Category → System
3. Click **Nvidia Driver (Proprietary)**
4. Reboot

Or from terminal:
```bash
sudo apk add nvidia-driver nvidia-firmware
sudo reboot
```

## 11. Gaming

### Steam
1. Lumina Store → Games → **Steam** → Install
2. Launch Steam from the taskbar or app launcher
3. Sign in, download your games
4. Proton is bundled — Windows games run out of the box

### Lutris (for Epic, GOG, Battle.net, emulators)
1. Lumina Store → Games → **Lutris** → Install
2. Connect your accounts in Lutris

### Performance tools (pre-installed)
- **MangoHud** — overlay FPS / CPU / GPU: `mangohud steam`
- **Gamemode** — auto-boost CPU governor: `gamemoderun ./game`

## 12. Troubleshooting

### Won't boot
- Try the **nomodeset** entry in the boot menu (disables GPU drivers)
- If still stuck, boot into **Recovery mode** → TTY → `apk fix`

### Wi-Fi not detected
- Likely missing firmware. Recovery mode → `sudo apk add linux-firmware-iwlwifi` (Intel) or `linux-firmware-rtw88` (Realtek)

### Audio not working
- Right-click speaker icon → **Audio settings**
- Check output device is set correctly
- If PipeWire died: `systemctl --user restart pipewire` (this is an Alpine system, so use `rc-service pipewire restart`)

### Forgot password
- Boot Recovery mode → TTY → `mount /dev/sdXN /mnt && chroot /mnt` → `passwd <username>`

### App not in store
- Try Flatpak: `flatpak search <name>`
- Try Alpine: `apk search <name>`
- If neither has it, you can enable the **AUR bridge** in Lumina Store settings (advanced)

## 13. Updating

LuminaOS checks for updates daily and shows a notification in the taskbar.
To update manually:

1. Open Lumina Store → **Updates** tab → **Update all**
2. Or terminal: `sudo apk upgrade && flatpak update`

Reboot only if the kernel was updated.

## 14. Uninstalling

If you want to remove LuminaOS and revert to Windows:
1. Boot from a Windows installation USB
2. Open `cmd` as admin → `diskpart` → `clean` on the LuminaOS disk
3. Reinstall Windows

(There's no in-place uninstall — it's an OS, not an app.)

## 15. Getting help

- **GitHub Issues**: <https://github.com/salom600/LuminaOS/issues>
- **Wiki**: <https://github.com/salom600/LuminaOS/wiki>
- **Discussions**: <https://github.com/salom600/LuminaOS/discussions>

When reporting issues, please include:
- `lumina-info` output (run from terminal)
- `journalctl -b` last 50 lines
- Hardware: `lspci -nnk | grep -A3 VGA`
