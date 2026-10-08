# Vectob OS 0.1 Alpha 🍐
Experimental **Ubuntu 12.04.2 i386** desktop image builder for **original UTM on iPhone**. This is a customized Ubuntu remix, **not an independently maintained Linux distribution**.

## Build
Run **Actions → Build Vectob OS 0.1 → Run workflow**. The runner downloads the official Ubuntu ISO, checks its checksum, extracts the desktop filesystem, constructs an MBR/ext4 disk, installs BIOS GRUB, and publishes `vectob-0.1-i386.img.zst` on the private **Releases** page.

## UTM setup
1. Download the release `.img.zst` (NOT the source code zip).
2. Decompress it on a computer with `zstd -d vectob-0.1-i386.img.zst`. You need ~8 GB free during decompression; the raw IMG is sparse on capable filesystems.
3. In original UTM, create an **Emulate → Linux** machine: **i386/i440fx**, **2048 MB RAM**, **1 CPU**, standard **VGA**, **IDE disk**, **Legacy BIOS**.
4. Import the decompressed `.img` as its primary IDE drive. Do not attach an installer ISO. Boot it.

**User:** vector · **Hostname:** vectob · **Login:** automatic. The account has a locked password and passwordless sudo; this is intentionally insecure. **Keep the guest offline.**

## Alpha limitations
Old Ubuntu 12.04 is unsupported. The wallpaper and desktop theme are Vectob-branded, while the desktop uses Ubuntu's included Unity 2D where available. A macOS-style bottom dock isn't bundled yet, to avoid extra legacy-repository downloads. **The initial image has not been verified on an iPhone's UTM until a successful test boot.**