# LuminaOS Contribution Guide

## Project structure

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the layered model.
Short version:

- `build/` — produces the ISO. `build.sh` is the entry point.
- `build/overlay/` — files injected into the live rootfs.
- `desktop/` — copy of desktop configs for easy browsing (not used at build time).
- `docs/` — design documents.
- `.github/workflows/` — CI.

## Local build

```bash
sudo docker run --rm --privileged -v "$PWD":/work -w /work alpine:3.20 sh build/build.sh
```

ISO lands at `build/output/lumina-os-1.0.0-x86_64.iso`.

## Coding style

- Shell scripts: POSIX `sh` where possible, `bash` if needed. Run `shfmt -s -i 4`.
- Configs (Hyprland, Waybar, Wofi): keep comments.
- Docs: GitHub-flavored Markdown, ≤ 80 chars per line where possible.

## PR checklist

- [ ] Build passes locally in Docker
- [ ] Build passes on GitHub Actions (push to your fork first)
- [ ] New shell scripts have `set -eu` (or `set -euo pipefail` for bash)
- [ ] No secrets / tokens committed
- [ ] CHANGELOG.md updated

## Reporting issues

Open an issue at <https://github.com/salom600/LuminaOS/issues> with:

- `lumina-info` output (run from terminal)
- Hardware: `lspci -nnk | grep -A3 VGA`
- Last 50 lines of `journalctl -b`

## Security

Found a security issue? **Do not open a public issue.** Email `salom600`
via GitHub's private vulnerability reporting at
<https://github.com/salom600/LuminaOS/security/advisories/new>.
