# ARCHITECTURE — LuminaOS system design

This document describes how LuminaOS is assembled from base to bootable ISO
to running desktop. It is the canonical reference for anyone modifying the
build.

## 1. Layered model

```
┌──────────────────────────────────────────────────────────────────┐
│                       LuminaOS Desktop                            │
│  (Hyprland + Waybar + Wofi + Fluent GTK theme + Lumina Store)     │
├──────────────────────────────────────────────────────────────────┤
│                       LuminaOS Overlay                            │
│  (/etc configs, /root configs, /usr/share themes & apps)          │
├──────────────────────────────────────────────────────────────────┤
│   Alpine Linux 3.20 (musl, OpenRC, apk, Linux 6.6 LTS kernel)    │
├──────────────────────────────────────────────────────────────────┤
│                       Bare metal / VM                             │
└──────────────────────────────────────────────────────────────────┘
```

The bottom two layers are stock Alpine. The top two are us.

## 2. Boot flow

```
power-on
   │
   ▼
┌────────────────────────────────────────────────────────────────┐
│ UEFI firmware (or SeaBIOS for legacy) loads ISO bootloader      │
│ (syslinux for BIOS, GRUB for UEFI — both on the ISO)            │
└────────────────────────────────────────────────────────────────┘
   │
   ▼
┌────────────────────────────────────────────────────────────────┐
│ Linux kernel 6.6 LTS (lts = stable + long support)              │
│ initramfs (mkinitfs) mounts SquashFS root from ISO              │
└────────────────────────────────────────────────────────────────┘
   │
   ▼
┌────────────────────────────────────────────────────────────────┐
│ OpenRC init:                                                    │
│   1. hwclock      (sync clock)                                  │
│   2. modules      (load kernel modules)                         │
│   3. sysctl       (apply /etc/sysctl.d/*)                       │
│   4. hostname     (lumina-live)                                 │
│   5. loopback     (lo up)                                       │
│   6. udev         (device events)                               │
│   7. dbus         (session bus)                                 │
│   8. elogind      (session/seat management)                     │
│   9. networkmanager (Wi-Fi + Ethernet)                          │
│  10. polkit       (privilege escalation)                        │
│  11. ly           (display manager — auto-login live user)      │
└────────────────────────────────────────────────────────────────┘
   │
   ▼
┌────────────────────────────────────────────────────────────────┐
│ Ly starts Hyprland for the live user with /etc/ly/config.ini    │
└────────────────────────────────────────────────────────────────┘
   │
   ▼
┌────────────────────────────────────────────────────────────────┐
│ Hyprland loads:                                                 │
│   - /etc/skel/.config/hypr/hyprland.conf (or /root/.config/...) │
│   - Auto-starts waybar, hyprpaper, dunst                        │
│   - Loads GTK theme "Lumina-Fluent" via gsettings               │
└────────────────────────────────────────────────────────────────┘
   │
   ▼
┌────────────────────────────────────────────────────────────────┐
│ User sees LuminaOS desktop: blurred wallpaper, centered task-   │
│ bar, wofi launcher (Super key), desktop shortcut to installer   │
└────────────────────────────────────────────────────────────────┘
```

## 3. Filesystem layout on the live ISO

The live ISO is a SquashFS image (~250 MB compressed). At boot it is
union-mounted with a tmpfs overlay, so writes go to RAM.

```
/
├── bin/                 # busybox + coreutils symlinks
├── sbin/                # OpenRC + system tools
├── lib/                 # musl libc + kernel modules
├── usr/
│   ├── bin/             # hyprland, waybar, wofi, kitty, firefox, ...
│   ├── lib/             # package libraries
│   └── share/
│       ├── themes/Lumina-Fluent/      # our GTK theme
│       ├── icons/Tela/                # icon theme
│       ├── wallpapers/lumina.png      # default wallpaper
│       ├── applications/              # .desktop files
│       │   ├── lumina-store.desktop
│       │   ├── lumina-installer.desktop
│       │   └── firefox.desktop
│       └── lumina/                    # our scripts
│           ├── lumina-store.sh
│           ├── lumina-installer.sh
│           ├── first-boot.sh
│           └── optimize.sh
├── etc/
│   ├── os-release       # LuminaOS identity (see below)
│   ├── hostname         # "lumina-live"
│   ├── profile.d/lumina.sh   # PATH, color prompt
│   ├── init.d/          # OpenRC services (mostly stock)
│   ├── conf.d/          # service configs
│   ├── ly/              # display manager config
│   └── security/        # limits.conf tweaks
├── root/
│   └── .config/         # Hyprland, Waybar, Wofi, kitty configs
└── home/
    └── lumina/          # default live user (password: lumina)
```

## 4. /etc/os-release

```sh
NAME="LuminaOS"
ID=lumina
ID_LIKE=alpine
VERSION="1.0.0"
VERSION_ID=1.0
PRETTY_NAME="LuminaOS 1.0 (Aether)"
ANSI_COLOR="0;36"
HOME_URL="https://github.com/salom600/LuminaOS"
BUG_REPORT_URL="https://github.com/salom600/LuminaOS/issues"
```

## 5. Package selection (build/apks.list)

The full package list lives in `build/apks.list`. Highlights:

### System core
- `alpine-base`, `linux-lts`, `linux-firmware` (wifi + common)
- `openrc`, `busybox`, `busybox-extras`, `util-linux`
- `apk-tools`, `musl`, `musl-utils`, `gcompat` (for glibc binaries)

### Boot & init
- `mkinitfs`, `syslinux`, `grub`, `grub-efi`

### Device & session
- `udev`, `dbus`, `elogind`, `polkit`, `polkit-elogind`

### Network
- `networkmanager`, `networkmanager-wifi`, `wpa_supplicant`, `iwd`,
  `wireless-tools`, `iptables`

### Display
- `hyprland`, `hyprlang`, `hyprcursor`, `hyprpaper`
- `waybar`, `wofi`, `kitty`, `swaylock`, `swayidle`
- `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk`
- `polkit-gnome`, `ly` (display manager)
- `mesa-dri-gallium`, `mesa-egl`, `vulkan-loader`, `vulkan-tools`
- `pipewire`, `pipewire-pulse`, `wireplumber` (audio)

### Applications
- `firefox`, `thunar`, `file-roller`, `gvfs`
- `vim`, `htop`, `git`, `curl`, `wget`, `tmux`
- `flatpak` (app store backend)

### Theming
- `ttf-dejavu`, `font-noto`, `font-noto-cjk`, `font-noto-emoji`
- `papirus-icon-theme`, `adwaita-icon-theme`
- `gtk-engines`, `gtk+3.0-dev` (for theming runtime)

## 6. RAM & CPU optimization tricks

These are applied by `scripts/optimize.sh` on first boot:

| Trick | Effect |
|---|---|
| `vm.swappiness=10` + `vm.vfs_cache_pressure=50` | Less swap pressure, more aggressive cache reclaim |
| `kernel.printk=3 3 3 3` | Quiet kernel log |
| Disable `audit`, `cpufreq-stats` kernel modules | Saves ~5 MB RAM |
| Mask `ntpd`, `chronyd` (use systemd-timesyncd — wait, no systemd) → use `openrc-settingsd` | One time-sync daemon only |
| `NetworkManager --no-daemon` with `--dhcp=internal` | Drops dhcpcd dependency |
| `pipewire` with `default.config.example` stripped | Audio stack uses ~15 MB instead of ~40 MB |
| `hyprpaper` instead of `swaybg` + `feh` | One wallpaper daemon, not two |
| No `gnome-keyring`, no `kwallet` by default | Saves ~20 MB; users can opt in via Lumina Store |
| TTYs reduced from 6 to 2 (`/etc/inittab`) | Saves ~3 MB |
| `zram` swap device (50 % of RAM, lz4) | Effectively doubles RAM on low-spec machines |

## 7. Installer design

We do not write our own installer. We use **Calamares** with a custom
LuminaOS branding module. Calamares is the installer used by Manjaro,
Lubuntu, KaOS, etc. — battle-tested, looks modern, supports both BIOS
and UEFI, and handles LUKS, dual-boot, and partition resizing.

`installer/lumina-installer.sh` is a thin wrapper that:
1. Checks for ≥ 8 GB disk space
2. Confirms with a Zenity dialog
3. Launches Calamares with our config (`/etc/calamares/settings.conf`)
4. On success, offers to reboot

## 8. Lumina Store design

`store/lumina-store.sh` is a bash + Zenity GUI over `apk` and `flatpak`.
It exposes:

- **Featured** (curated short list)
- **Browsing** (Firefox, Chromium, Vivaldi)
- **Games** (Steam via Flatpak, RetroArch, 0 AD, SuperTuxKart)
- **Media** (VLC, mpv, OBS, GIMP, Krita)
- **Office** (LibreOffice via Flatpak, OnlyOffice)
- **Development** (VSCode, Vim, Git, Docker)
- **System** (already-installed apps, updates)

Each category lists packages with icons, descriptions, and one-click
"Install" / "Uninstall" / "Update" buttons. Under the hood every action
is just `apk add` / `flatpak install` / etc., wrapped in a `pkexec`
prompt for privilege.

## 9. CI pipeline (GitHub Actions)

```
push to main / tag v* / manual dispatch
              │
              ▼
   ubuntu-22.04 runner
              │
              ▼
   docker run alpine:3.20
              │
              ▼
   apk add mkimage, all build deps
              │
              ▼
   ./build/build.sh
              │
              ▼
   build/lumina-os-<ver>-x86_64.iso (~250 MB)
              │
              ▼
   upload-artifact  (always, 90-day retention)
              │
              ▼
   if tag v*: gh release create, attach ISO + SHA256
```

The job typically finishes in 15–25 minutes. The runner has 4 vCPUs /
16 GB RAM, which is plenty for `mkimage`.

## 10. Release versioning

- `v1.0.0` — first public release
- Tags trigger releases; every push to `main` triggers an artifact-only build
- ISO filename: `lumina-os-<version>-x86_64.iso`
- Always shipped with a `.sha256` checksum

## 11. Security model

- Live user `lumina` has password `lumina` and passwordless sudo (live only)
- After install, the user sets their own password; root is locked, sudo via `wheel` group
- App store installs use `pkexec` (polkit) — no root terminal needed
- Flatpak apps run sandboxed by default
- Firewall: `nftables` with a default-deny input chain (only DHCP, mDNS, SSH if enabled)
