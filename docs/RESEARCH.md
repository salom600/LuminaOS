# RESEARCH — Choosing the base distribution

This document records the analysis performed before choosing the base for
LuminaOS. The decision is **Alpine Linux 3.20**, and the reasoning is below.

## 1. Constraints from the project brief

The brief asks for three things simultaneously:

1. **Extremely lightweight** — target 100 MB RAM at idle, ~0 % CPU.
2. **Modern, transparent, Windows-11/macOS-class desktop** — implies Wayland
   compositor with blur, a themable bar, modern GTK/Qt theming.
3. **Friendly to Windows refugees** — one-click installer, app store,
   familiar taskbar / start-menu UX.

The first constraint rules out anything heavier than ~300 MB ISO. The second
rules out bare TTY / Tiling-only-WMs-with-no-blur. The third rules out "expert
distros" that ship without an installer or a GUI store.

## 2. Candidates considered

| Distro | Base ISO | RAM idle | Init | Libc | Installer | App store | Notes |
|---|---|---|---|---|---|---|---|
| **Alpine** | **~50 MB** | **~20 MB** | OpenRC | musl | setup-alpine (text) + our Calamares | apk + our wrapper | Docker-grade minimal |
| Arch Linux | ~800 MB | ~120 MB | systemd | glibc | archinstall (text) | pacman + AUR | Excellent docs, but heavy |
| Artix (Arch w/o systemd) | ~700 MB | ~100 MB | OpenRC/runit | glibc | cli only | pacman + AUR | Niche, fewer packages |
| Void Linux | ~350 MB | ~80 MB | runit | musl OR glibc | cli only | xbps | Solid, but smaller community |
| Tiny Core Linux | ~16 MB | ~30 MB | custom | glibc | cli only | tce-load | Too minimal — no Wayland story |
| Debian minimal (netinst) | ~400 MB | ~120 MB | systemd | glibc | debian-installer | apt | Heavy for this purpose |
| Linux From Scratch | n/a | n/a | n/a | n/a | none | none | Educational only — not viable on CI in 6 h |
| NixOS minimal | ~500 MB | ~180 MB | systemd | glibc | nixos-installer | nix | Powerful but conceptually heavy for Windows users |

## 3. Decision matrix (weighted)

Weights: Lightness 30 %, Modern desktop support 20 %, Installer ease 20 %,
CI build time 15 %, Community/package availability 15 %.

| Distro | Light (30) | Desktop (20) | Installer (20) | CI time (15) | Community (15) | **Total** |
|---|---|---|---|---|---|---|
| **Alpine** | **10** | 7 | 6 (after Calamares overlay) | **10** | 7 | **8.2** |
| Arch | 5 | 10 | 7 | 5 | 10 | 7.2 |
| Artix | 6 | 9 | 4 | 6 | 6 | 6.3 |
| Void | 8 | 8 | 4 | 8 | 6 | 6.9 |
| Tiny Core | 10 | 2 | 2 | 9 | 3 | 5.4 |
| Debian min | 5 | 8 | 8 | 6 | 10 | 7.0 |
| NixOS min | 4 | 8 | 8 | 4 | 8 | 6.1 |

**Winner: Alpine Linux.**

## 4. Why Alpine specifically

### 4.1 Footprint
The Alpine base ISO is roughly 50 MB. A full desktop install with Hyprland,
Waybar, Wofi, kitty, Thunar, Firefox, and our custom theme lands around
250 MB on disk and ~120 MB in RAM at idle. That is an order of magnitude
lighter than Ubuntu (~1.8 GB ISO, ~600 MB RAM) and half the size of a minimal
Debian desktop.

### 4.2 musl libc
musl produces smaller, statically-linkable binaries. It also has a smaller
attack surface than glibc. The cost is that some proprietary binaries (e.g.
older Nvidia drivers, some closed-source games) require glibc — for those,
we ship `gcompat` which provides a glibc-compatible shim. This is good
enough for the gaming-curious user we are targeting.

### 4.3 OpenRC, not systemd
systemd is great on servers, but on a desktop aimed at "0 % CPU at idle"
it pulls in journald, logind, networkd, resolved, udevd, oomd, etc. OpenRC
with the right service list runs maybe 4 daemons at boot (udev, dbus, elogind,
NetworkManager) and nothing else. We save 20–40 MB of RAM and one or two
percent of CPU just from this choice.

### 4.4 apk
apk is the fastest mainstream package manager, with the smallest metadata
footprint. It supports "virtual" packages (so we can declare `lumina-desktop`
as a meta-package that pulls in Hyprland + Waybar + Wofi + kitty + ...),
signed indices, and delta downloads. Perfect for an app-store UX.

### 4.5 CI friendliness
Alpine publishes an official `alpine:latest` Docker image that we can use
inside GitHub Actions. Combined with `apk add --no-cache` and `mkimage`,
we can produce an ISO inside a 20-minute CI job. This is critical because
GitHub's free tier caps a single job at 6 hours.

### 4.6 Production-grade
Alpine is the base for Docker official images, WireGuard routers, k3s nodes,
and PostmarketOS phones. It is not a toy distro.

## 5. Known trade-offs we accept by choosing Alpine

| Trade-off | Mitigation |
|---|---|
| Some glibc-only proprietary software won't run | Ship `gcompat`; document Flatpak as the preferred app source for closed-source apps |
| Smaller package count than Arch/Debian | Use Flatpak for desktop GUI apps; keep Alpine packages for system & core tools |
| musl occasionally slower on heavy numeric code | Acceptable for the target user (browse, game casually, write) |
| `mkimage` is less polished than `archiso` | We write our own `build.sh` that wraps `mkimage` with our overlay logic |

## 6. Desktop stack chosen

After picking Alpine, we evaluated Wayland compositors:

| Compositor | RAM | Blur? | Animations? | Modern look? |
|---|---|---|---|---|
| **Hyprland** | ~50 MB | yes | yes | **yes** |
| Sway | ~30 MB | no (patched forks only) | limited | flat |
| Weston | ~25 MB | no | no | dated |
| Cage (kiosk) | ~15 MB | no | no | n/a |

We pick **Hyprland** because blur + rounded corners + smooth animations are
required to deliver the "Windows 11 / macOS" feel the brief asks for. The
~20 MB RAM overhead vs Sway is acceptable.

On top of Hyprland we layer:

- **Waybar** — bar, themed as a centered Win11-style taskbar
- **Wofi** — app launcher, themed as a Win11-style start menu
- **kitty** — GPU-accelerated terminal
- **Thunar** — file manager (lighter than Nautilus)
- **Fluent-inspired GTK theme** — transparent, rounded, Win11 colors
- **Tela icon theme** — modern, colorful, Win11-style
- **swaylock / hyprpaper** — lock screen + wallpaper
- **polkit-gnome** — privilege escalation dialogs
- **xdg-desktop-portal-hyprland** — Flatpak & screenshot support

## 7. Build & release strategy

We avoid `archiso` (Arch-specific) and `live-build` (Debian-specific).
Instead we use Alpine's `mkimage` tool, which produces an `alpine-virt`
style ISO with our overlay overlaid on top. The CI pipeline in
`.github/workflows/build-iso.yml` runs this inside the official
`alpine:latest` Docker image, so the build is fully reproducible and
does not depend on the runner's host OS.

## 8. Conclusion

LuminaOS = **Alpine Linux 3.20** base + **Hyprland** compositor + custom
**Lumina desktop** (Waybar + Wofi + Fluent-inspired GTK theme) + custom
**Lumina Store** (GUI over apk + Flatpak) + **Calamares** installer.

This stack is the smallest credible foundation that still delivers the
modern, transparent, Windows-11-class UX the brief requires.
