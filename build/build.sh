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
mkdir -p "$ROOTFS/etc/apk"
cp /etc/apk/repositories "$ROOTFS/etc/apk/repositories"
apk --root "$ROOTFS" --initdb --no-cache add \
    alpine-base \
    busybox \
    busybox-extras \
    openrc \
    musl \
    musl-utils \
    gcompat

# 3b. Add the kernel
apk --root "$ROOTFS" --no-cache add \
    linux-lts \
    linux-firmware \
    linux-firmware-i915 \
    linux-firmware-amdgpu \
    linux-firmware-rtw88 \
    linux-firmware-iwlwifi

# 3c. Add every package from apks.list
echo "==> [4/7] Installing package list from $APKS_LIST"
# shellcheck disable=SC2046
apk --root "$ROOTFS" --no-cache add $(sed 's/#.*//' "$APKS_LIST" | xargs)

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
chroot "$ROOTFS" mkinitfs -c /etc/mkinitfs/mkinitfs.conf "$(ls /lib/modules)"

# --- 4. Build the SquashFS --------------------------------------------------
echo "==> [6/7] Packing rootfs into SquashFS"
SQUASHFS="$WORK_DIR/lumina.squashfs"
mksquashfs "$ROOTFS" "$SQUASHFS" -comp zstd -Xcompression-level 19 -noappend -no-progress

# --- 5. Build the ISO -------------------------------------------------------
echo "==> [7/7] Assembling bootable ISO"
ISO_ROOT="$WORK_DIR/iso"
mkdir -p "$ISO_ROOT/boot" "$ISO_ROOT/lumina" "$ISO_ROOT/efi/boot"

# copy kernel + initramfs
KERNEL_VER=$(ls "$ROOTFS/lib/modules" | head -1)
cp "$ROOTFS/boot/vmlinuz-$KERNEL_VER" "$ISO_ROOT/boot/vmlinuz"
cp "$ROOTFS/boot/initramfs-$KERNEL_VER" "$ISO_ROOT/boot/initramfs"

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
