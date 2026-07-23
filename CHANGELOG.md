# Changelog

All notable changes to LuminaOS are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] — 2026-07-24
### Added
- Initial release of LuminaOS, codenamed "Aether".
- Alpine Linux 3.20 base, musl libc, OpenRC init.
- Hyprland Wayland compositor with blur, rounded corners, animations.
- Waybar configured as a centered, translucent Windows 11-style taskbar.
- Wofi configured as a translucent Windows 11-style start menu.
- Fluent-inspired GTK theme + Tela icon theme.
- Lumina Store — GUI over apk + Flatpak with Featured / Browsing / Games / Media / Office / Development categories.
- One-click installer (Calamares wrapper) — accessible from desktop and launcher.
- First-boot OpenRC service that sets up zram swap, Flathub remote, NM autoconnect.
- Lumina Optimize OpenRC service — applies CPU governor, ASPM, USB autosuspend, audio power save.
- GitHub Actions workflow `build-iso.yml` — builds ISO on push and on tag.
- Documentation: README, RESEARCH, ARCHITECTURE, FEATURES, USAGE.

### Known limitations
- Nvidia proprietary driver must be installed from Lumina Store after first boot.
- Some closed-source games requiring glibc-specific ABIs may need `gcompat`.
- Touch support is limited (Hyprland upstream limitation).
