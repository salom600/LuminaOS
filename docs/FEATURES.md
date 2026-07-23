# FEATURES — LuminaOS feature list

## Pillar 1 — Extremely lightweight

| Feature | Value | How |
|---|---|---|
| Idle RAM | ~100–120 MB | Alpine base + OpenRC, no systemd, no gnome-keyring, zram swap |
| Idle CPU | < 1 % (effectively 0 %) | Only 4 daemons: udev, dbus, elogind, NetworkManager |
| Boot time | < 15 s on HDD, < 8 s on SSD | SquashFS live root, parallel OpenRC services |
| ISO size | ~250 MB | Stripped firmware, only common drivers on ISO; rest downloaded on first boot |
| Disk install size | ~1.5 GB | No docs, no man pages for unused locales, single kernel |
| Battery life | +20 % vs Ubuntu on same hardware | No background indexers, no telemetry, no snapd |

## Pillar 2 — Modern, sleek, transparent design

- **Hyprland compositor** with blur (kwin-style), rounded corners, smooth animations
- **Translucent panels** — Waybar at 70 % opacity with gaussian blur behind it
- **Fluent-inspired GTK theme** — Win11 color palette (#0078D4 accent), rounded buttons, transparent menus
- **Tela icon theme** — colorful, modern, Win11-style
- **Acrylic / Mica effect** on terminal and file manager via Hyprland blur
- **Animated workspace switcher** — slide animation between virtual desktops
- **Lock screen** — swaylock with blurred wallpaper behind, clock + date
- **Cursor theme** — Bibata modern cursors
- **Default wallpaper** — Lumina gradient (deep blue → cyan → magenta), 4K
- **Dark mode by default** — Win11 dark theme palette; light mode available

## Pillar 3 — Friendly to Windows refugees

### Installer
- **One-click installer** on the desktop — double-click, click "Install", done
- **Calamares-powered** — same installer Manjaro / Lubuntu use, supports dual-boot
- **No command line required** for the whole install → first boot → browse flow
- **Auto-detects** EFI vs BIOS, existing OS installs, swap partitions
- **Optional full-disk encryption** with LUKS, presented as a simple checkbox

### App store (Lumina Store)
- Single window with sidebar categories: Featured / Browsing / Games / Media / Office / Development / System
- Big icons, descriptions, ratings, one-click Install
- Update all button in toolbar
- Search bar with fuzzy matching
- Sources: Alpine `apk` (system) + Flathub (apps)
- Optional: enable AUR-style user repo via `yay` (off by default, can be toggled)

### Windows-like UX conventions
- **Super key** (Windows key) opens app launcher
- **Super + E** opens file manager (like Windows)
- **Super + D** shows desktop
- **Alt + Tab** switches windows
- **Ctrl + Shift + Esc** opens htop-like task manager
- **PrtScn** opens screenshot tool
- **Taskbar at bottom, centered** (Win11 style)
- **System tray** with network, volume, battery, clock
- **Right-click on desktop** for context menu (display settings, wallpaper)

### Browser & codecs
- Firefox pre-installed with uBlock Origin
- H.264 / H.265 / AAC / MP3 playback out of the box (via `ffmpeg`)
- Widevine enabled in Firefox for Netflix / Spotify web

### Gaming
- **Steam** installable from Lumina Store (one click, Flatpak)
- **Proton** bundled with Steam
- **Lutris** available for non-Steam games
- **MangoHud** for FPS overlay
- **Gamemode** for CPU governor boost
- **Drivers**: Mesa RADV (AMD) and Intel out of the box; Nvidia driver installable from store

## Convenience features
- **Auto-updates** notification (does not auto-install; user clicks Update)
- **Built-in firewall** (nftables, default-deny inbound)
- **Time machine** style snapshots via `btrfs-snp` if installed on btrfs
- **Recovery mode** in GRUB — boots to a TTY with `apk` available to fix the system
- **Live USB persistence** option in installer — writes changes back to USB

## Accessibility
- On-screen keyboard (`wtype` + `squeekboard`)
- High contrast theme variant
- Screen reader: `orca` installable from store
- Magnifier: `wl-mirror` + Hyprland zoom

## Internationalization
- Default locale: `en_US.UTF-8`
- Available locales: en, ar, fr, es, de, it, pt, ru, zh, ja, ko
- IBus + Anthy, Pinyin, Mozc for CJK input
- RTL support for Arabic / Hebrew desktop

## Out of scope (for v1.0)
- Server / headless variant (use Alpine directly)
- Touch-first tablet UX (Hyprland has limited touch support; revisit in v1.1)
- Phone variant (PostmarketOS already does this better)
- Pre-installed Office suite (download from store — keeps ISO small)
