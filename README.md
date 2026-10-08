# Vectob OS 0.1 Alpha 🍐🐧

A custom **Ubuntu 12.04.2 i386** desktop image built by GitHub Actions for the original UTM iPhone app. This is a small Ubuntu remix, not a separately maintained distribution.

### Download for iPhone
1. Go to **Releases → v0.1-alpha**.
2. Download **Vectob-OS-0.1-i386.zip** (~650 MB). ZIP is supported by iPhone Files.
3. Open the ZIP in Files; it expands to **vectob-0.1-i386.img** (8 GB). Make sure your iPhone has ample free space.
4. In **original UTM**, create **Emulate → Linux → i386 (Intel i440FX)**, with 2048 MB RAM, 1 CPU, VGA, legacy BIOS and an IDE disk. Use the extracted **.img** as the VM's disk.
5. Boot without the Ubuntu installer ISO. If UTM can't import the IMG as a disk, choose **Existing Image** when adding a drive.

### Alpha specification
* Genuine Ubuntu 12.04.2 desktop filesystem, from an official ISO whose SHA256 is verified during build.
* Hostname **vectob**, username **vector**; auto login.
* Password locked, passwordless sudo; **keep the VM offline**.
* 8 GiB MBR/ext4 disk with GRUB BIOS boot; data persists.
* Branded macOS-inspired wallpaper and Unity 2D when available. A complete bottom macOS dock is **not** yet included.
* The GitHub Actions image-building process passed, but **boot on UTM/iPhone is not yet verified**.

### Builder source
* `scripts/build-vectob.sh`: builds `vectob-0.1-i386.img.zst`.
* `.github/workflows/build-vectob.yml`: builds the OS and publishes initial release.
* `.github/workflows/repack-iphone.yml`: publishes a ZIP for iPhone Files.

This is an unsupported legacy Ubuntu release for offline experimentation only.