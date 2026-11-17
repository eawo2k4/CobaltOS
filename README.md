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

Also included: Winetricks, GameMode, MangoHud, Gamescope and ProtonUp-Qt.

> **Note:** CobaltOS does not include any copy of Windows. To use 86Box with Windows 3.1/95/98/ME you'll need your own install media. 86Box also needs its ROM set, which is available from the [86Box ROMs repository](https://github.com/86Box/roms).

## Installation

> [!WARNING]
> CobaltOS is experimental. Try it in a VM or on a spare drive first.

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

## ISO

You can generate an offline installer ISO by following the [BlueBuild ISO guide](https://blue-build.org/how-to/generate-iso/). ISOs are too big to host on GitHub for free, so public releases need other hosting.

## For developers

- `recipes/common-gaming.yml` holds the packages and apps shared by every edition. Edit this one to change what's installed.
- `recipes/recipe.yml` / `recipes/recipe-nvidia.yml` are the per-edition recipes (base image and name).
- `files/system/` is copied into the image root, for config files and branding.
- Every push to GitHub rebuilds the images through GitHub Actions. They also rebuild daily to pick up Fedora updates.

## Verification

Images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). To verify, download `cosign.pub` from this repo and run:

```bash
cosign verify --key cosign.pub ghcr.io/eawo2k4/cobaltos
```
