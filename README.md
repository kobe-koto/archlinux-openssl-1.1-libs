# OpenSSL 1.1 Custom Repository for Arch Linux

An Arch Linux repository providing prebuilt binaries for **OpenSSL 1.1**.

**Included Packages:**

- openssl-1.1 (1.1.1.w-5)
- lib32-openssl-1.1 (1.1.1.w-3)
- Debug symbols (`-debug`) are also available for both packages

## Usage

1. Add the Repository

   Add the following block to the end of your `/etc/pacman.conf`:

   ```ini
   [openssl-1.1-libs]
   SigLevel = Optional TrustAll
   Server = https://al-openssl-1-1-libs.pages.dev/x86_64
   ```

2. Sync and Install

   Update your package databases and install the desired packages:

   > [!TIP]
   > Since these are legacy libraries, it is recommended to install them with the `--asdeps` flag when there's a package requiring them. 
   > `--asdeps` marks packages as dependencies.

   ```bash
   # Sync 
   sudo pacman -Sy
   # Optional: Install libraries
   sudo pacman -S openssl-1.1 lib32-openssl-1.1
   # Optional: Install debug symbols
   sudo pacman -S openssl-1.1-debug lib32-openssl-1.1-debug
   ```

## Thanks

### PKGBUILDs from AUR: 

- https://aur.archlinux.org/packages/openssl-1.1
- https://aur.archlinux.org/packages/lib32-openssl-1.1

## Licensing

- **Repository:** Licensed under the [MIT License](https://www.google.com/search?q=LICENSE).
- **Compiled Binaries:** Subject to the **OpenSSL and SSLeay Licenses**. See `LICENSE-OPENSSL` for details.

## Disclaimer

**Use at your own risk.** I hold no responsibility and provide no warranty for the use of this repository.

These packages are built on a [clean Arch Linux container](https://docker.io/library/archlinux:latest) via Distrobox.

