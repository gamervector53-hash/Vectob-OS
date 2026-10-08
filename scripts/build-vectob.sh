#!/usr/bin/env bash
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

ISO_URL="https://old-releases.ubuntu.com/releases/12.04.0/ubuntu-12.04.2-desktop-i386.iso"
SUMS_URL="https://old-releases.ubuntu.com/releases/12.04.0/SHA256SUMS"
ISO="/tmp/vectob-ubuntu.iso"
SQUASH="/tmp/vectob-filesystem.squashfs"
IMG="$GITHUB_WORKSPACE/output/vectob-0.1.1-i386.img"
ROOT="/mnt/vectob-root"
LOOP=""
MOUNTED=0
BINDS=()

cleanup() {
  set +e
  for path in "${BINDS[@]}"; do sudo umount -lf "$ROOT/$path"; done
  if [ "$MOUNTED" -eq 1 ]; then sudo umount -lf "$ROOT"; fi
  if [ -n "$LOOP" ]; then sudo losetup -d "$LOOP"; fi
}
trap cleanup EXIT

sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends curl xorriso squashfs-tools parted e2fsprogs grub-pc-bin grub2-common qemu-utils qemu-system-x86 zstd
mkdir -p output
echo "Downloading official Ubuntu 12.04.2 32-bit Desktop ISO..."
curl --fail --location --retry 5 --retry-delay 8 "$ISO_URL" -o "$ISO"
curl --fail --location --retry 5 "$SUMS_URL" -o /tmp/vectob-SHA256SUMS
expected=$(awk '/ubuntu-12.04.2-desktop-i386.iso$/ {print $1; exit}' /tmp/vectob-SHA256SUMS)
test -n "$expected"
printf '%s  %s\n' "$expected" "$ISO" | sha256sum -c -
echo "ISO hash verified against official Ubuntu checksum list."

xorriso -osirrox on -indev "$ISO" -extract /casper/filesystem.squashfs "$SQUASH"
truncate -s 8G "$IMG"
parted -s "$IMG" mklabel msdos
parted -s "$IMG" mkpart primary ext4 1MiB 100%
parted -s "$IMG" set 1 boot on

LOOP=$(sudo losetup --find --show --partscan "$IMG")
sudo udevadm settle
PART="${LOOP}p1"
if [ ! -b "$PART" ]; then
  sudo partprobe "$LOOP"
  sleep 2
fi
test -b "$PART"
# Ubuntu 12.04's 3.5 kernel cannot mount modern ext4 metadata_csum / orphan_file features.
sudo mkfs.ext4 -F -L VECTOB -O ^64bit,^metadata_csum,^orphan_file "$PART"
features=$(sudo tune2fs -l "$PART" | sed -n 's/^Filesystem features: *//p')
echo "Vectob ext4 filesystem features: $features"
if echo " $features " | grep -Eq ' (64bit|metadata_csum|orphan_file) '; then
  echo "ERROR: filesystem contains features unsupported by the Ubuntu 12.04 kernel" >&2
  exit 1
fi
sudo mkdir -p "$ROOT"
sudo mount "$PART" "$ROOT"
MOUNTED=1
sudo unsquashfs -f -d "$ROOT" "$SQUASH"
test -x "$ROOT/bin/bash"

echo "Setting up persistent Ubuntu desktop..."
echo vectob | sudo tee "$ROOT/etc/hostname" >/dev/null
printf '127.0.0.1 localhost\n127.0.1.1 vectob\n::1 localhost ip6-localhost ip6-loopback\n' | sudo tee "$ROOT/etc/hosts" >/dev/null
printf 'LABEL=VECTOB / ext4 errors=remount-ro 0 1\n' | sudo tee "$ROOT/etc/fstab" >/dev/null
sudo rm -f "$ROOT/etc/udev/rules.d/70-persistent-net.rules"
sudo mkdir -p "$ROOT/proc" "$ROOT/sys" "$ROOT/dev" "$ROOT/boot/grub"
for pair in "dev:/dev" "proc:/proc" "sys:/sys"; do
  name="${pair%%:*}"
  path="${pair#*:}"
  sudo mount --bind "$path" "$ROOT/$name"
  BINDS=("$name" "${BINDS[@]}")
done
if ! sudo chroot "$ROOT" id vector >/dev/null 2>&1; then
  sudo chroot "$ROOT" useradd -m -s /bin/bash -U vector
fi
groups=""
for g in adm cdrom sudo dip plugdev audio video lpadmin; do
  if grep -q "^$g:" "$ROOT/etc/group"; then
    if [ -n "$groups" ]; then groups="$groups,$g"; else groups="$g"; fi
  fi
done
sudo chroot "$ROOT" usermod -aG "$groups" vector
sudo chroot "$ROOT" passwd -l vector
sudo mkdir -p "$ROOT/etc/sudoers.d" "$ROOT/etc/lightdm"
printf 'vector ALL=(ALL) NOPASSWD:ALL\n' | sudo tee "$ROOT/etc/sudoers.d/99-vectob" >/dev/null
sudo chmod 440 "$ROOT/etc/sudoers.d/99-vectob"

session=ubuntu
if [ -e "$ROOT/usr/share/xsessions/ubuntu-2d.desktop" ]; then session=ubuntu-2d; fi
printf '[SeatDefaults]\nautologin-user=vector\nautologin-user-timeout=0\nuser-session=%s\nallow-guest=false\n' "$session" | sudo tee "$ROOT/etc/lightdm/lightdm.conf" >/dev/null

sudo mkdir -p "$ROOT/usr/share/backgrounds" "$ROOT/usr/share/glib-2.0/schemas"
sudo cp artwork/vectob-wallpaper.svg "$ROOT/usr/share/backgrounds/Vectob.svg"
sudo tee "$ROOT/usr/share/glib-2.0/schemas/90_vectob.gschema.override" >/dev/null <<'GSETTINGS'
[org.gnome.desktop.background]
picture-uri='file:///usr/share/backgrounds/Vectob.svg'
picture-options='zoom'
primary-color='#111c3f'
GSETTINGS
sudo chroot "$ROOT" glib-compile-schemas /usr/share/glib-2.0/schemas
sudo mkdir -p "$ROOT/etc/skel/.config/gtk-3.0"
printf '[Settings]\ngtk-theme-name=Ambiance\ngtk-icon-theme-name=ubuntu-mono-dark\n' | sudo tee "$ROOT/etc/skel/.config/gtk-3.0/settings.ini" >/dev/null
sudo cp -r "$ROOT/etc/skel/." "$ROOT/home/vector/" || true
sudo chroot "$ROOT" chown -R vector:vector /home/vector

# Disable archive updates: this alpha intentionally works offline.
sudo sed -i 's/^deb /# deb /' "$ROOT/etc/apt/sources.list" || true
sudo mkdir -p "$ROOT/etc/init"
sudo tee "$ROOT/etc/init/vectob-smoketest.conf" >/dev/null <<'SMOKE'
description "Vectob first-boot self test"
start on runlevel [2345]
task
script
  if [ -c /dev/ttyS0 ]; then
    echo VECTOB_ROOT_MOUNTED > /dev/ttyS0
    n=0
    while [ "$n" -lt 80 ]; do
      if pidof lightdm >/dev/null 2>&1; then
        echo VECTOB_LIGHTDM_STARTED > /dev/ttyS0
        exit 0
      fi
      n=$((n + 1))
      sleep 2
    done
    echo VECTOB_LIGHTDM_NOT_STARTED > /dev/ttyS0
  fi
end script
SMOKE
test -x "$ROOT/usr/sbin/lightdm"
sudo tee "$ROOT/etc/motd" >/dev/null <<'MOTD'
Vectob OS 0.1 Alpha
Ubuntu 12.04 i386 foundation Ã¢ÂÂ offline experimental build.
MOTD

kernel=$(find "$ROOT/lib/modules" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -V | tail -n1)
test -n "$kernel"
echo "Configuring kernel: $kernel"
if [ ! -f "$ROOT/boot/vmlinuz-$kernel" ]; then
  sudo xorriso -osirrox on -indev "$ISO" -extract /casper/vmlinuz "$ROOT/boot/vmlinuz-$kernel"
fi
sudo chroot "$ROOT" update-initramfs -c -k "$kernel" || sudo chroot "$ROOT" update-initramfs -u -k "$kernel"
test -s "$ROOT/boot/initrd.img-$kernel"
sudo tee "$ROOT/boot/grub/grub.cfg" >/dev/null <<GRUB
set default=0
set timeout=2
insmod part_msdos
insmod ext2
search --no-floppy --label VECTOB --set=root
menuentry 'Vectob OS 0.1 Alpha' {
  linux /boot/vmlinuz-$kernel root=LABEL=VECTOB ro console=tty0 console=ttyS0,115200n8
  initrd /boot/initrd.img-$kernel
}
GRUB
sudo grub-install --target=i386-pc --boot-directory="$ROOT/boot" --recheck "$LOOP"

# Flush and detach before compressing, so the released image is consistent.
sudo sync
for path in "${BINDS[@]}"; do sudo umount "$ROOT/$path"; done
BINDS=()
sudo umount "$ROOT"
MOUNTED=0
sudo losetup -d "$LOOP"
LOOP=""
echo "Disk image built:"
file "$IMG"
qemu-img info "$IMG"

# Verify that the custom image boots into Linux userspace and starts LightDM.
# This catches exactly the initramfs shell regression seen on the iPhone.
echo "Smoke-testing i386 BIOS boot in QEMU (software emulation)..."
BOOTLOG="$GITHUB_WORKSPACE/output/vectob-boot-serial.log"
VMLOG="$GITHUB_WORKSPACE/output/vectob-qemu.log"
: > "$BOOTLOG"
qemu-system-i386 -machine pc -accel tcg -m 1024 -smp 1 \
  -drive file="$IMG",format=raw,if=ide \
  -vga std -display none -serial "file:$BOOTLOG" \
  -monitor none -net none -no-reboot > "$VMLOG" 2>&1 &
QEMU_PID=$!
PASSED=0
for i in $(seq 1 65); do
  if grep -q VECTOB_LIGHTDM_STARTED "$BOOTLOG"; then
    PASSED=1
    break
  fi
  if ! kill -0 "$QEMU_PID" 2>/dev/null; then
    break
  fi
  sleep 5
done
kill "$QEMU_PID" 2>/dev/null || true
wait "$QEMU_PID" 2>/dev/null || true
if [ "$PASSED" -ne 1 ]; then
  echo "ERROR: Vectob did not reach the LightDM desktop service in the emulator."
  echo "=== Guest serial log ==="
  tail -100 "$BOOTLOG" || true
  echo "=== QEMU log ==="
  tail -40 "$VMLOG" || true
  exit 1
fi
echo "PASS: boot reached Linux userspace and started LightDM."
# This headless test checks service startup, not visible desktop rendering in UTM.
zstd -T0 -7 --rm -f "$IMG" -o "$IMG.zst"
sha256sum "$IMG.zst" > "$IMG.zst.sha256"
ls -lh "$IMG.zst" "$IMG.zst.sha256"
