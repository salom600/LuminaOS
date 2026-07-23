#!/bin/sh
# ============================================================================
#  LuminaOS — ISO build script
#  Runs inside an alpine:3.20 container (or Alpine host) and produces
#  a bootable hybrid ISO at build/output/lumina-os-<ver>-x86_64.iso
# ============================================================================
set -eu

# --- paths ------------------------------------------------------------------
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
OVERLAY="$HERE/overlay"
APKS_LIST="$HERE/apks.list"
OUTPUT_DIR="$ROOT/build/output"
WORK_DIR="$ROOT/build/work"
VERSION="$(cat "$ROOT/VERSION" 2>/dev/null || echo "1.0.0")"
ARCH="${ARCH:-x86_64}"
ISO_NAME="lumina-os-${VERSION}-${ARCH}.iso"

# --- banner -----------------------------------------------------------------
cat <<EOF

================================================================
  LuminaOS build
  Version : $VERSION
  Arch    : $ARCH
  Output  : $OUTPUT_DIR/$ISO_NAME
================================================================

EOF

# --- 1. Make sure we are on Alpine -----------------------------------------
if ! grep -qi alpine /etc/os-release 2>/dev/null; then
    echo "ERROR: this script must run inside an Alpine container or host."
    echo "       Try: docker run --rm --privileged -v \"\$PWD\":/work -w /work \\"
    echo "             alpine:3.20 sh build/build.sh"
    exit 1
fi

# --- 2. Install build deps --------------------------------------------------
echo "==> [1/7] Installing build dependencies"
apk update
apk add --no-cache \
    alpine-sdk \
    apk-tools \
    syslinux \
    grub \
    grub-efi \
    mtools \
    dosfstools \
    xorriso \
    squashfs-tools \
    mkinitfs \
    busybox-extras \
    linux-firmware \
    cpio \
    findutils \
    ca-certificates \
    brotli \
    zstd

# --- 3. Prepare overlay -----------------------------------------------------
echo "==> [2/7] Preparing overlay filesystem"
ROOTFS="$WORK_DIR/rootfs"
rm -rf "$WORK_DIR"
mkdir -p "$ROOTFS"

# 3a. Bootstrap a minimal Alpine rootfs via apk --initdb
echo "==> [3/7] Bootstrapping Alpine rootfs"
mkdir -p "$ROOTFS/etc/apk/keys"
# CRITICAL: copy Alpine signing keys so apk trusts the package indices
cp /etc/apk/keys/* "$ROOTFS/etc/apk/keys/" 2>/dev/null || true
# Explicitly enable both main and community for v3.20 — do not rely on the
# host's repositories file, because some alpine:3.20 images only ship `main`.
cat > "$ROOTFS/etc/apk/repositories" <<EOF
https://dl-cdn.alpinelinux.org/alpine/v3.20/main
https://dl-cdn.alpinelinux.org/alpine/v3.20/community
EOF
apk --root "$ROOTFS" --initdb --no-cache update
apk --root "$ROOTFS" --initdb --no-cache add \
    alpine-base \
    busybox \
    busybox-extras \
    openrc \
    musl \
    musl-utils \
    gcompat

# 3b. Add the kernel + firmware (meta linux-firmware pulls in all sub-packages)
echo "==> [4/7] Installing package list from $APKS_LIST"

# Tolerant installer: try a BULK install first (fast + atomic).  If the bulk
# install fails because some packages are missing, parse the error, drop the
# missing packages, and retry.  This is much more reliable than per-package
# install because per-package install leaves the apk database in a bad state
# after the first failure and every subsequent install also fails.
MISSING_LOG="$WORK_DIR/missing-packages.log"
: > "$MISSING_LOG"

# Read all non-comment, non-blank lines from apks.list
PKGS=""
while IFS= read -r line; do
    line="${line%%#*}"
    line="$(echo "$line" | tr -d '[:space:]')"
    [ -z "$line" ] && continue
    PKGS="$PKGS $line"
done < "$APKS_LIST"

# Also include kernel + firmware explicitly
PKGS="linux-lts linux-firmware $PKGS"

echo "  Bulk-installing $(echo $PKGS | wc -w) packages ..."
ATTEMPTS=0
MAX_ATTEMPTS=8
while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
    ATTEMPTS=$((ATTEMPTS + 1))
    ERRORS=$(apk --root "$ROOTFS" --no-cache add $PKGS 2>&1) && {
        echo "  [+] bulk install succeeded on attempt $ATTEMPTS"
        break
    }
    # Parse out the missing package names from the error
    NEW_MISSING=$(echo "$ERRORS" | grep -oE '  [a-zA-Z0-9_.+-]+ \(no such package\):' | sed -E 's/^  //; s/ \(no such package\)://')
    if [ -z "$NEW_MISSING" ]; then
        # No (no such package) errors found — something else broke.
        echo "$ERRORS" | tail -10
        echo "  [!] bulk install failed for non-missing-package reason (see above)."
        break
    fi
    echo "  [!] attempt $ATTEMPTS: missing $(echo $NEW_MISSING | tr '\n' ' ')"
    for missing in $NEW_MISSING; do
        echo "$missing" >> "$MISSING_LOG"
        PKGS="$(echo " $PKGS " | sed "s/ $missing / /")"
    done
done

MISSING_COUNT=$(wc -l < "$MISSING_LOG" | tr -d ' ')
if [ "$MISSING_COUNT" -gt 0 ]; then
    echo
    echo "==> WARNING: $MISSING_COUNT package(s) not found in Alpine 3.20 repos:"
    sort -u "$MISSING_LOG" | sed 's/^/      - /'
    echo "    These were skipped. Edit build/apks.list if you need them."
    echo
fi

# 3d. Copy our overlay on top
echo "==> [5/7] Applying LuminaOS overlay"
cp -a "$OVERLAY/." "$ROOTFS/"

# 3e. Identity / branding
mkdir -p "$ROOTFS/etc"
cat > "$ROOTFS/etc/os-release" <<EOF
NAME="LuminaOS"
ID=lumina
ID_LIKE=alpine
VERSION="$VERSION"
VERSION_ID="$(echo "$VERSION" | cut -d. -f1,2)"
PRETTY_NAME="LuminaOS $VERSION (Aether)"
ANSI_COLOR="0;36"
HOME_URL="https://github.com/salom600/LuminaOS"
BUG_REPORT_URL="https://github.com/salom600/LuminaOS/issues"
EOF

echo "lumina-live" > "$ROOTFS/etc/hostname"

# 3f. Enable OpenRC services
for svc in devfs dmesg mdev hwclock modules sysctl hostname bootmisc syslog \
           networking dbus elogind networkmanager polkit ly pipewire; do
    if [ -x "$ROOTFS/etc/init.d/$svc" ]; then
        chroot "$ROOTFS" rc-update add "$svc" default 2>/dev/null || true
    fi
done

# 3g. Set up the live user
chroot "$ROOTFS" sh -c '
    adduser -D -G wheel -s /bin/sh lumina
    echo "lumina:lumina" | chpasswd
    echo "root:root" | chpasswd
    addgroup lumina input
    addgroup lumina video
    addgroup lumina audio
    addgroup lumina plugdev
' 2>/dev/null || true

# 3h. Live-session /etc/inittab (only 2 ttys)
cat > "$ROOTFS/etc/inittab" <<'EOF'
::sysinit:/sbin/openrc sysinit
::sysinit:/sbin/openrc boot
::wait:/sbin/openrc default

tty1::respawn:/sbin/getty 38400 tty1
tty2::respawn:/sbin/getty 38400 tty2

::shutdown:/sbin/openrc shutdown
EOF

# 3i. mkinitfs config — include kernel modules needed for boot from ISO
cat > "$ROOTFS/etc/mkinitfs/mkinitfs.conf" <<'EOF'
features="ata base ide scsi usb virtio ext4 squashfs iso9660 vfat fs-uuid resume"
EOF

# 3j. Regenerate initramfs
# IMPORTANT: list /lib/modules *inside* the rootfs, not on the build host.
# Otherwise we pick up the host kernel version (e.g. Ubuntu's 6.8.0-azure)
# which doesn't exist in the chroot.
KERNEL_VER=$(ls "$ROOTFS/lib/modules" 2>/dev/null | head -1)
if [ -z "$KERNEL_VER" ]; then
    echo "ERROR: no kernel modules found in $ROOTFS/lib/modules — was linux-lts installed?"
    exit 1
fi
echo "  Regenerating initramfs for kernel $KERNEL_VER"
chroot "$ROOTFS" mkinitfs -c /etc/mkinitfs/mkinitfs.conf "$KERNEL_VER"

# --- 4. Build the SquashFS --------------------------------------------------
echo "==> [6/7] Packing rootfs into SquashFS"
SQUASHFS="$WORK_DIR/lumina.squashfs"
mksquashfs "$ROOTFS" "$SQUASHFS" -comp zstd -Xcompression-level 19 -noappend -no-progress

# --- 5. Build the ISO -------------------------------------------------------
echo "==> [7/7] Assembling bootable ISO"
ISO_ROOT="$WORK_DIR/iso"
mkdir -p "$ISO_ROOT/boot" "$ISO_ROOT/lumina" "$ISO_ROOT/efi/boot"

# copy kernel + initramfs
# Alpine installs /boot/vmlinuz-lts and mkinitfs creates /boot/initramfs-lts
# (stable symlinks).  Prefer those; fall back to version-suffixed names.
KERNEL_VER=$(ls "$ROOTFS/lib/modules" | head -1)
if [ -e "$ROOTFS/boot/vmlinuz-lts" ]; then
    cp "$ROOTFS/boot/vmlinuz-lts" "$ISO_ROOT/boot/vmlinuz"
elif [ -e "$ROOTFS/boot/vmlinuz-$KERNEL_VER" ]; then
    cp "$ROOTFS/boot/vmlinuz-$KERNEL_VER" "$ISO_ROOT/boot/vmlinuz"
else
    echo "ERROR: cannot find kernel image in $ROOTFS/boot/"
    ls -la "$ROOTFS/boot/" 2>&1 | head -20
    exit 1
fi

if [ -e "$ROOTFS/boot/initramfs-lts" ]; then
    cp "$ROOTFS/boot/initramfs-lts" "$ISO_ROOT/boot/initramfs"
elif [ -e "$ROOTFS/boot/initramfs-$KERNEL_VER" ]; then
    cp "$ROOTFS/boot/initramfs-$KERNEL_VER" "$ISO_ROOT/boot/initramfs"
else
    echo "ERROR: cannot find initramfs in $ROOTFS/boot/"
    ls -la "$ROOTFS/boot/" 2>&1 | head -20
    exit 1
fi

# copy squashfs
cp "$SQUASHFS" "$ISO_ROOT/lumina/lumina.squashfs"

# bootloader config — syslinux (BIOS)
cat > "$ISO_ROOT/boot/syslinux.cfg" <<'EOF'
DEFAULT lumina
PROMPT 0
TIMEOUT 30

LABEL lumina
    MENU LABEL ^LuminaOS (default)
    LINUX /boot/vmlinuz
    INITRD /boot/initramfs
    APPEND modules=loop,squashfs,sd-mod,usb-storage quiet \
           lumina.live=/lumina/lumina.squashfs

LABEL lumina-nomodeset
    MENU LABEL LuminaOS (nomodeset — for flickering screens)
    LINUX /boot/vmlinuz
    INITRD /boot/initramfs
    APPEND modules=loop,squashfs,sd-mod,usb-storage quiet \
           nomodeset lumina.live=/lumina/lumina.squashfs

LABEL lumina-debug
    MENU LABEL LuminaOS (debug — verbose boot)
    LINUX /boot/vmlinuz
    INITRD /boot/initramfs
    APPEND modules=loop,squashfs,sd-mod,usb-storage \
           lumina.live=/lumina/lumina.squashfs
EOF

mkdir -p "$ISO_ROOT/boot/syslinux"
cp "$ISO_ROOT/boot/syslinux.cfg" "$ISO_ROOT/boot/syslinux/syslinux.cfg"
# copy syslinux files from build host
for f in isolinux.bin ldlinux.c32 menu.c32 libutil.c32 libcom32.c32 vesamenu.c32; do
    cp "/usr/share/syslinux/$f" "$ISO_ROOT/boot/syslinux/" 2>/dev/null || true
done

# bootloader config — grub (UEFI)
cat > "$ISO_ROOT/efi/boot/grub.cfg" <<'EOF'
set timeout=30
set default=0

menuentry "LuminaOS (default)" {
    linux /boot/vmlinuz modules=loop,squashfs,sd-mod,usb-storage quiet \
           lumina.live=/lumina/lumina.squashfs
    initrd /boot/initramfs
}

menuentry "LuminaOS (nomodeset)" {
    linux /boot/vmlinuz modules=loop,squashfs,sd-mod,usb-storage quiet \
           nomodeset lumina.live=/lumina/lumina.squashfs
    initrd /boot/initramfs
}

menuentry "LuminaOS (debug)" {
    linux /boot/vmlinuz modules=loop,squashfs,sd-mod,usb-storage \
           lumina.live=/lumina/lumina.squashfs
    initrd /boot/initramfs
}
EOF

# build a tiny standalone GRUB EFI binary
grub-mkstandalone \
    --format x86_64-efi \
    --output "$ISO_ROOT/efi/boot/bootx64.efi" \
    --modules "part_gpt part_msdos fat squashfs iso9660 loopback normal \
               echo ls linux multiboot2 boot configfile" \
    "boot/grub/grub.cfg=$ISO_ROOT/efi/boot/grub.cfg" 2>/dev/null || true

# also place an isolinux.bin at the root for xorriso's -isohybrid
cp /usr/share/syslinux/isolinux.bin "$ISO_ROOT/isolinux.bin" 2>/dev/null || true
cp /usr/share/syslinux/ldlinux.c32  "$ISO_ROOT/ldlinux.c32"  2>/dev/null || true

# assemble ISO with xorriso (BIOS + UEFI hybrid)
mkdir -p "$OUTPUT_DIR"
xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "LUMINAOS" \
    -eltorito-boot boot/syslinux/isolinux.bin \
    -eltorito-catalog boot/syslinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -isohybrid-mbr /usr/share/syslinux/isohdpfx.bin \
    -eltorito-alt-boot \
    -e efi/boot/bootx64.efi \
    -no-emul-boot -isohybrid-gpt-basdat \
    -output "$OUTPUT_DIR/$ISO_NAME" \
    "$ISO_ROOT"

# sha256
( cd "$OUTPUT_DIR" && sha256sum "$ISO_NAME" > "$ISO_NAME.sha256" )

# --- 6. Summary -------------------------------------------------------------
echo
echo "================================================================"
echo "  Build complete"
echo "  ISO    : $OUTPUT_DIR/$ISO_NAME"
echo "  Size   : $(du -h "$OUTPUT_DIR/$ISO_NAME" | cut -f1)"
echo "  SHA256 : $OUTPUT_DIR/$ISO_NAME.sha256"
echo "================================================================"
