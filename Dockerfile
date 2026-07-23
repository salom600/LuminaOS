# LuminaOS Dockerfile — local build environment
# Use this if you want to build the ISO without installing Alpine.

FROM alpine:3.20

# Build deps
RUN apk update && apk add --no-cache \
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
      cpio \
      findutils \
      ca-certificates \
      brotli \
      zstd \
      bash \
      git \
      curl \
      docker-cli

WORKDIR /work

# Default: run the build script
CMD ["sh", "build/build.sh"]
