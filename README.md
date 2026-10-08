# Vectob OS 0.1.1 Alpha (boot fix)

Experimental Ubuntu 12.04.2 i386 desktop image for original UTM on iPhone.

## Updated boot fix
The original Vectob 0.1 release reached the BusyBox initramfs emergency shell. The new builder formats ext4 with Ubuntu-3.5-compatible options (no metadata_csum, 64bit, orphan_file), creates legacy BIOS GRUB, boots the resulting raw IMG under QEMU, and **refuses to publish** if Linux and the LightDM service do not start. The QEMU test does not prove desktop pixels render in UTM; the final iPhone boot must be verified there.

## Download / UTM
Use [Releases](../../releases/tag/v0.1.1-alpha) and download the iPhone Files ZIP when published. Extract **vectob-0.1.1-i386.img** and replace the disk in original UTM (i386, i440FX, 2 GiB RAM, 1 CPU core, VGA, IDE disk, legacy BIOS). Do not attach the Ubuntu installer ISO. The disk is 8 GiB uncompressed and has persistent ext4 storage.

Login is automatic as **vector**, hostname **vectob**, with passwordless sudo by design. **Keep it offline**: Ubuntu 12.04 is unsupported. Vectob styling currently includes branded wallpaper; a macOS-style dock remains future work.
