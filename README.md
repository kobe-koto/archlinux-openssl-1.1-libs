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
   Server = https://al-openssl-1-1-libs.pages.dev/repo/$repo
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

#### Host Requirements (pacstrap only)

- Host is Arch Linux

  **Enable repositories**: `core`, `extra`, `multilib`

  **Packages**: `arch-install-scripts`

- Other Distros

  Install `pacman` and `arch-install-scripts`, then follow "Host is Arch Linux".

#### Container Requirements

If you choose to set up the build environment manually, the container must have:

- **Repositories Enabled**: `core`, `extra`, `multilib`
- **Packages:** `base`, `base-devel`, `multilib-devel`, `git`.
- **User:** A user named `worker` (default) with `NOPASSWD` sudo privileges.
- **Security:** A fully populated and initialized `pacman-key`.

**Non-Arch users:** Please refer to [ArchWiki: Install Arch Linux from existing Linux: From a host running another Linux distribution](https://wiki.archlinux.org/title/Install_Arch_Linux_from_existing_Linux#From_a_host_running_another_Linux_distribution).

#### Option A: Using `Systemd-nspawn` (Root Required)

This method uses a localized container (defaulting to `./archlinux-build/`). 

If the directory is missing, the script will attempt to build a new chroot environment.

- `bootstrap` mode

  This script will download a latest bootstrap tarball, initialize and populate the keyring, enable `multilib` repo, and install required packages (see above)

- `pacstrap` mode

  Uses system's `pacstrap`, see "Host Requirements (pacstrap only)".

```bash
bash build.sh --nspawn=[bootstrap|pacstrap]
```

#### Option B: Using [Distrobox](https://distrobox.it)

Uses [library/archlinux:multilib-devel](https://docker.io/library/archlinux:multilib-devel).

Ideal for users on other distributions or those who prefer Distrobox for environment isolation. 

We recommend installing Distrobox via your package manager first; otherwise, the script will attempt a standalone installation.

```bash
bash build.sh --distrobox
```

### Select AUR packages

The default package list is the `DEFAULT_AUR_PACKAGES` Bash array in `build.sh`.
To override it for a run, pass package names as positional arguments. Both container
modes accept the same list:

```bash
packages=("openssl-1.1" "lib32-openssl-1.1")
bash build.sh --nspawn=bootstrap "${packages[@]}"
# Or: bash build.sh --distrobox "${packages[@]}"
```

Packages are checked, built, and collected using this list. Put dependencies before
packages that need them; for example, `openssl-1.1` precedes `lib32-openssl-1.1`.
Omitting package arguments keeps the default list.

### Temporary space

Set `TMP_SIZE` to mount `/var/tmp/aur-builder` as tmpfs with a capacity limit
and pass it to build tools as `TMPDIR`. This keeps temporary files separate from
Distrobox's shared host `/tmp`. Set `BUILD_TMP_SIZE` independently for the
`/build` directory used by the builder:

```bash
TMP_SIZE=8G BUILD_TMP_SIZE=16G bash build.sh --nspawn=bootstrap "${packages[@]}"
# Or: TMP_SIZE=8G BUILD_TMP_SIZE=16G bash build.sh --distrobox "${packages[@]}"
```

Accepted values are positive byte counts or K/M/G/T suffixes. Unset variables
keep the container's default mounts. These are tmpfs
capacity limits, not per-user disk quotas; actual use consumes memory and swap.
The build mount allows execution for configure checks and compiled test tools.
If a PKGBUILD or makepkg configuration sets `BUILDDIR` elsewhere, that directory
is outside the `/build` limit.

For Distrobox, configure these values when creating the container. To change
them for an existing `archlinux-build` container, stop and remove that container
with Distrobox before running the script again.

### Optional mold linker

Set `ENABLE_MOLD=1` to use `mold -run` for package builds:

```bash
ENABLE_MOLD=1 bash build.sh --nspawn=bootstrap "${packages[@]}"
# Can be combined with TMP_SIZE, BUILD_TMP_SIZE, and CUSTOM_REPO.
```

The container installs `mold` if it is missing, then runs
`runuser -u worker -- mold -run makepkg ...` for each package. The wrapper is
started after switching users so its environment reaches the build tools.
Unset or `ENABLE_MOLD=0` keeps the normal linker; other values are rejected.
Disabling it on a later run does not uninstall mold, but stops using the wrapper.
Packages whose versions are already current still skip compilation; changing
this flag alone does not force a rebuild.

### Optional Clang/LLVM toolchain

Set `ENABLE_LLVM=1` to build with Clang and LLVM tools:

```bash
ENABLE_LLVM=1 bash build.sh --nspawn=bootstrap "${packages[@]}"
```

The container installs `clang`, `llvm`, and `lld` if the required tools are
missing. A temporary makepkg configuration loads the usual system and worker
settings, then selects `CC=clang`, `CXX=clang++`, `AR=llvm-ar`,
`RANLIB=llvm-ranlib`, and `NM=llvm-nm`. It uses LLD unless `ENABLE_MOLD=1`
selects the existing `mold -run` wrapper. The system configuration is not edited,
and the temporary file is removed after success or failure.

Unset or `ENABLE_LLVM=0` keeps the normal toolchain; other values are rejected.
PKGBUILDs that hardcode compiler commands can override this selection. Changing
the flag does not force a rebuild of already-current package versions.

### Output

Set `CUSTOM_REPO` to override the repository name (default: `openssl-1.1-libs`):

```bash
packages=("openssl-1.1" "lib32-openssl-1.1")
CUSTOM_REPO=my-aur-repo bash build.sh --nspawn=bootstrap "${packages[@]}"
```

Packages, `<repo>.db*`, `<repo>.files*`, `lastupdate`, and `lastsync` are written
to `repo/$CUSTOM_REPO/`, without an architecture subdirectory. The transfer
archive is `dist/<repo>.tar`. Use the same repository name in `/etc/pacman.conf`
and point `Server` at the directory containing the database and packages.

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
