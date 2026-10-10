# Vectob 0.2 Secure Boot work

The `secure-boot.yml` workflow fetches Ubuntu distribution-signed shim, GRUB and kernel and inspects their signatures with `sbverify`. It publishes them as *components only*.

**Not yet a Secure Boot-capable Vectob ISO.** The experimental live ISO builder currently uses an unsigned GRUB and a Debian Bookworm root filesystem/kernel. Mixing the Ubuntu signed components into that ISO without a properly validated trust chain would be unsafe and might not boot.

Next steps:
1. Standardize the ISO on one supported distribution/version (Ubuntu with its signed chain, or Debian with Debian-signed shim/GRUB/kernel).
2. Construct a UEFI El Torito/FAT EFI boot image with signed shim as `EFI/BOOT/BOOTX64.EFI`, matching signed GRUB and its configuration, and the distro-signed kernel.
3. Verify shim trust/revocation status, kernel signatures and boot configuration. Test under OVMF with Secure Boot and enrolled keys, then on actual Lenovo hardware only after verifying BitLocker recovery readiness.
4. Check compressed ISO size against the under-1000-MB target. Do not promise it until measured.

Keep Windows 11, its EFI partition, and Secure Boot settings unchanged. Do not write this prototype to the USB yet.
