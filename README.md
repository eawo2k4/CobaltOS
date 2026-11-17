# CobaltOS &nbsp; [![bluebuild build badge](https://github.com/eawo2k4/cobaltos/actions/workflows/build.yml/badge.svg)](https://github.com/eawo2k4/cobaltos/actions/workflows/build.yml)

**CobaltOS** is a Fedora Atomic–based Linux distro for playing your old Windows games, from Windows 3.1 through XP and beyond, on modern hardware. It's built with [BlueBuild](https://blue-build.org) on top of [Universal Blue](https://universal-blue.org).

## Editions

| Image | Desktop | Graphics |
|---|---|---|
| `ghcr.io/eawo2k4/cobaltos` | KDE Plasma | AMD / Intel |
| `ghcr.io/eawo2k4/cobaltos-nvidia` | KDE Plasma | NVIDIA (drivers preinstalled) |

## Which tool for which game?

| Era | Use | Why |
|---|---|---|
| DOS / Windows 3.1 | **DOSBox-X** | Wine's 16-bit support is unreliable |
| Windows 95 / 98 / ME | **86Box** | Emulates a real 90s PC (Voodoo, S3, Sound Blaster...) so picky games just work |
| Windows 98SE – XP (DirectX 7–9) | **Lutris** or **Bottles** (Wine + DXVK) | Fast, runs natively on your GPU |
| Vista and newer | **Steam** (Proton) or Lutris | Usually works great |

Also included: Winetricks, GameMode, MangoHud, Gamescope, ProtonUp-Qt and the official 86Box ROM set.

## Welcome Center

On login, the **CobaltOS Welcome** app helps you get started:

- **Welcome:** pick the era of your game and jump straight to the right tool
- **86Box setup:** checks 86Box and its ROMs, with recommended virtual PCs for Windows 3.1 to ME
- **Graphics:** shows your graphics card and driver, and tells you if you're on the wrong edition
- **Help:** links to PCGamingWiki, WineHQ, ProtonDB, Lutris, VOGONS and more

You can turn it off at login with the checkbox, and reopen it any time from the app menu.

> **Note:** CobaltOS does not include any copy of Windows. To use 86Box with Windows 3.1/95/98/ME you'll need your own install media. 86Box also needs its ROM set, which is available from the [86Box ROMs repository](https://github.com/86Box/roms).

## Installation

> [!WARNING]
> CobaltOS is experimental. Try it in a VM or on a spare drive first.

The easiest way is the [installer ISO](#installer-iso). Or, if you already run a Fedora Atomic desktop, rebase to CobaltOS:

Install any Fedora Atomic desktop (for example [Fedora Kinoite](https://fedoraproject.org/atomic-desktops/kinoite/)), then rebase to CobaltOS. Swap `cobaltos` for `cobaltos-nvidia` if you have an NVIDIA card.

1. Rebase to the unsigned image first, to get the signing keys and policies installed:
   ```
   rpm-ostree rebase ostree-unverified-registry:ghcr.io/eawo2k4/cobaltos:latest
   ```
2. Reboot:
   ```
   systemctl reboot
   ```
3. Rebase to the signed image:
   ```
   rpm-ostree rebase ostree-image-signed:docker://ghcr.io/eawo2k4/cobaltos:latest
   ```
4. Reboot again:
   ```
   systemctl reboot
   ```

The Fedora version is set by `image-version` in the recipes, so you won't jump to a new Fedora release by accident.

## Installer ISO

The `build-iso` workflow builds an offline installer ISO for each edition. It uses Fedora's normal graphical installer: pick a disk, create your user, and reboot into CobaltOS.

1. Go to **Actions** → **build-iso** → **Run workflow**. A run takes about 30–60 minutes.
2. Open the finished run and download **cobaltos-iso** or **cobaltos-nvidia-iso** from the Artifacts section. You need to be signed in to GitHub, and the artifacts are kept for 30 days.
3. Unzip the download, then write `cobaltos.iso` to a USB stick (8 GB or larger) with [Fedora Media Writer](https://fedoraproject.org/workstation/download) or [Rufus](https://rufus.ie) (use "DD image" mode), or boot it in a VM.
4. Check the download if you like: `sha256sum -c cobaltos.iso.sha256`

The installed system updates itself from `ghcr.io/eawo2k4/cobaltos`. Apps like 86Box and Steam install in the background on first boot, so give it a few minutes online.

ISOs are too big for GitHub Releases (2 GB limit), so a public download needs other hosting later (for example SourceForge or the Internet Archive).

## For developers

- `recipes/common-gaming.yml` holds the packages and apps shared by every edition. Edit this one to change what's installed.
- `recipes/recipe.yml` / `recipes/recipe-nvidia.yml` are the per-edition recipes (base image and name).
- `files/system/` is copied into the image root, for config files and branding:
  - `usr/bin/cobalt-welcome`: the Welcome Center (Python + PyQt6)
  - `usr/share/icons/hicolor/scalable/apps/cobaltos.svg`: the CobaltOS logo
  - `etc/xdg/kcm-about-distrorc`: logo and links on KDE's "About this System" page
- `files/scripts/cobalt-setup.sh` runs during the build.
- The `check` workflow smoke-tests the Welcome Center headlessly on every push.
- Every push to GitHub rebuilds the images through GitHub Actions. They also rebuild daily to pick up Fedora updates.

## Verification

Images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). To verify, download `cosign.pub` from this repo and run:

```bash
cosign verify --key cosign.pub ghcr.io/eawo2k4/cobaltos
```
