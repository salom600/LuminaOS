# LuminaOS

> **Light as air. Sharp as light.**
> A custom, ultra-lightweight Linux distribution with a modern, transparent desktop — designed for users coming from Windows.

[![Build ISO](https://github.com/salom600/LuminaOS/actions/workflows/build-iso.yml/badge.svg)](https://github.com/salom600/LuminaOS/actions/workflows/build-iso.yml)
![ISO Size](https://img.shields.io/badge/ISO-~250MB-blueviolet)
![RAM at idle](https://img.shields.io/badge/RAM%20idle-~120MB-success)
![License](https://img.shields.io/badge/license-MIT-green)

---

## What is LuminaOS?

LuminaOS is a from-scratch Linux distribution built on top of **Alpine Linux**, customized to deliver three things at the same time — things that normally contradict each other:

| Pillar | Target | How we hit it |
|---|---|---|
| **Extremely lightweight** | ~100 MB RAM at idle, < 1 % CPU | Alpine base (musl libc, OpenRC, no systemd), no daemons unless explicitly enabled, lazy-loaded services |
| **Modern, sleek, transparent design** | Look & feel on par with Windows 11 / macOS | Hyprland Wayland compositor with blur & rounded corners, custom Fluent-inspired GTK theme, translucent panels |
| **Friendly to Windows refugees** | One-click install, app store, familiar UX | Calamares-based installer, custom `lumina-store` GUI over `apk`, Win11-style taskbar & start menu via Waybar + Wofi |

## Why Alpine?

After comparing every credible lightweight base (Alpine, Arch, TinyCore, Void, Slackware, Debian-minimal), Alpine wins decisively for this project. See [`docs/RESEARCH.md`](docs/RESEARCH.md) for the full analysis. Short version:

- **Smallest base footprint** — base install ~50 MB ISO, ~20 MB RAM at idle
- **musl libc** — smaller binaries, smaller attack surface
- **OpenRC, not systemd** — we control what runs, no hidden daemons
- **apk package manager** — faster than apt, lighter than dnf
- **Production-grade** — used in Docker images, routers, k8s nodes worldwide

## Project layout

```
lumina-os/
├── build/            # ISO build system (Alpine mkimage + overlay)
│   ├── build.sh
│   ├── apks.list
│   └── overlay/      # Files injected into the live ISO
├── desktop/          # Hyprland, Waybar, Wofi, terminal, themes
├── store/            # Lumina Store — GUI over apk
├── installer/        # One-click installer (Calamares + lumina-installer)
├── scripts/          # first-boot, optimization, user-setup
├── docs/             # RESEARCH, ARCHITECTURE, FEATURES, USAGE
└── .github/workflows/build-iso.yml   # CI that builds the ISO
```

## Building locally

You need Docker (or Podman). No Alpine host required.

```bash
git clone https://github.com/salom600/LuminaOS.git
cd LuminaOS
sudo docker run --rm --privileged -v "$PWD":/work -w /work alpine:latest sh build/build.sh
# ISO appears at build/lumina-os-<version>-x86_64.iso
```

## Building on GitHub Actions

Just push to `main` (or trigger the workflow manually from the Actions tab). The workflow in `.github/workflows/build-iso.yml` will:

1. Spin up an Alpine container inside the Ubuntu runner
2. Install `mkimage` + all packages from `build/apks.list`
3. Overlay our custom desktop config, theme, store, and installer
4. Produce a bootable hybrid ISO (~250 MB)
5. Upload it as a workflow artifact and as a GitHub Release (on tags)

The build typically finishes in 15–25 minutes, well under GitHub's 6-hour job limit.

## Downloading the ISO

Once a build is green:

1. Go to **Actions → Build ISO → latest run → Artifacts**
2. Download `lumina-os-iso` (ZIP containing the ISO)
3. Flash to USB: `dd if=lumina-os-*.iso of=/dev/sdX bs=4M conv=fsync status=progress`
   Or use Rufus / balenaEtcher on Windows.

## Booting & installing

1. Boot from USB. LuminaOS live session starts in < 15 seconds.
2. Click **Install LuminaOS** on the desktop (one-click installer, Calamares-powered).
3. Pick disk → set timezone → create user → done in ~5 minutes.
4. Reboot into your new system.

See [`docs/USAGE.md`](docs/USAGE.md) for the full walk-through.

## Project goals (and non-goals)

### Goals
- Boot-to-desktop in under 15 seconds on a 10-year-old laptop
- Idle RAM under 150 MB (target 100 MB)
- Idle CPU under 1 % (target 0 %)
- A desktop that does not look like a 2008 Linux distro
- An app store a Windows user can use without reading docs
- Reproducible builds via GitHub Actions

### Non-goals (for v1.0)
- Server / headless variant (covered by Alpine itself)
- systemd (OpenRC is lighter and adequate for desktop)
- Wayland-only — no X11 fallback (Hyprland is Wayland-only, we accept this)
- Pre-installed proprietary GPU drivers (added on first boot if detected)

## License

MIT. See [`LICENSE`](LICENSE). Bundled components retain their own licenses (Alpine = MIT, Hyprland = BSD, etc.).

## Security note

**Never commit GitHub tokens or any other credentials to this repository.** The Actions workflow uses `secrets.GITHUB_TOKEN` (auto-injected by GitHub) for releases — no personal token needed. If you ever fork this project, do the same.
