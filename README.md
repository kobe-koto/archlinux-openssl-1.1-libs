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
   > 
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

## Build from Source

If you prefer to build the packages yourself to ensure integrity, you can use the provided automation scripts.

### Clone this repository

```bash
git clone https://github.com/kobe-koto/archlinux-openssl-1.1-libs/
cd archlinux-openssl-1.1-libs
```

### Run The Build Script

> [!CAUTION]
>
> **Review the scripts before execution.** 
>
> These scripts require **root/sudo** privileges to manage containers and install build dependencies.

#### Container Requirements

If you choose to set up the build environment manually, the container must have:

- **Packages:** `base`, `base-devel`, `multilib-devel`, `git`.
- **User:** A user named `worker` (default) with `NOPASSWD` sudo privileges.
- **Security:** A fully populated and initialized `pacman-key`.

#### Option A: Using `Systemd-nspawn` (Recommended for Arch Linux system, Root Required)

This method uses a localized container (defaulting to `./archlinux-build/`). 

If the directory is missing, the script will attempt to bootstrap it using `pacstrap` (requires `arch-install-scripts`).

**Non-Arch users:** Please refer to [ArchWiki: Install Arch Linux from existing Linux: From a host running another Linux distribution](https://wiki.archlinux.org/title/Install_Arch_Linux_from_existing_Linux#From_a_host_running_another_Linux_distribution).

```bash
bash build.sh --nspawn
```

#### Option B: Using [Distrobox](https://distrobox.it)

Uses [library/archlinux:multilib-devel](https://docker.io/library/archlinux:multilib-devel).

Ideal for users on other distributions or those who prefer Distrobox for environment isolation. 

We recommend installing Distrobox via your package manager first; otherwise, the script will attempt a standalone installation.

```bash
bash build.sh --distrobox
```

### Output

Once the build completes, the newly generated `.pkg.tar.zst` files and the updated repository database will replace the existing binaries in the `x86_64` directory.

## Thanks

### PKGBUILDs from AUR: 

- https://aur.archlinux.org/packages/openssl-1.1
- https://aur.archlinux.org/packages/lib32-openssl-1.1

## Licensing

- **Repository:** Licensed under the [MIT License](https://www.google.com/search?q=LICENSE).
- **Compiled Binaries:** Subject to the **OpenSSL and SSLeay Licenses**. See `LICENSE-OPENSSL` for details.

## Disclaimer

**Use at your own risk.** I hold no responsibility and provide no warranty for the use of this repository.

These packages are built on a [clean Arch Linux container](https://docker.io/library/archlinux:multilib-devel) via Distrobox, using [this script](https://github.com/kobe-koto/archlinux-openssl-1.1-libs/blob/main/build.sh).
