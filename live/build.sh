#!/usr/bin/bash
# Builds the CobaltOS live environment (runs inside `podman build`, see Containerfile).
# Based on Bazzite's installer/build.sh and Titanoboa's examples:
#   https://github.com/ublue-os/bazzite/tree/main/installer
#   https://github.com/ublue-os/titanoboa/tree/main/examples
set -exo pipefail

BASE_IMAGE=${BASE_IMAGE:?}
INSTALL_IMAGE_PAYLOAD=${INSTALL_IMAGE_PAYLOAD:?}
IMAGE_REF=${INSTALL_IMAGE_PAYLOAD%:*}
IMAGE_TAG=${INSTALL_IMAGE_PAYLOAD##*:}

# /root is a symlink on Atomic images; create its target
mkdir -p "$(realpath /root)"

# bwrap (used by flatpak) writes /proc/sys/user/max_user_namespaces
mount -o remount,rw /proc/sys

# --- Apps -------------------------------------------------------------------
# Install the Flatpak apps into the live system. The installer copies them to
# the new system, so nothing needs downloading after install.
curl --retry 3 -fLo /etc/flatpak/remotes.d/flathub.flatpakrepo https://dl.flathub.org/repo/flathub.flatpakrepo
xargs -r flatpak install -y --noninteractive flathub < /src/flatpaks

# --- System to install ------------------------------------------------------
podman pull "$INSTALL_IMAGE_PAYLOAD"
if [[ "$INSTALL_IMAGE_PAYLOAD" == *-nvidia* ]]; then
    touch /usr/share/cobaltos/live-nvidia
fi

# --- Live boot ----------------------------------------------------------------
dnf install -y dracut-live
kernel=$(kernel-install list --json pretty | jq -r '.[] | select(.has_kernel == true) | .version')
DRACUT_NO_XATTR=1 dracut -v --force --reproducible --no-hostonly \
    --add "dmsquash-live dmsquash-live-autooverlay" \
    "/usr/lib/modules/${kernel}/initramfs.img" "${kernel}"

# livesys creates the "liveuser" account and logs it into KDE automatically
dnf install -y livesys-scripts
sed -i "s/^livesys_session=.*/livesys_session=kde/" /etc/sysconfig/livesys
systemctl enable livesys.service livesys-late.service

# --- Installer (Anaconda) -----------------------------------------------------
dnf -qy versionlock clear || :
# Anaconda's web interface runs in an RPM Firefox
dnf install -y --enable-repo=fedora-cisco-openh264 --allowerasing \
    firefox anaconda-live libblockdev-{btrfs,lvm,dm} rsync mokutil yad
mkdir -p /var/lib/rpm-state

echo "CobaltOS release $(. /etc/os-release; echo "$VERSION_ID")" > /etc/system-release

mkdir -p /etc/anaconda/conf.d
cat > /etc/anaconda/conf.d/90-cobaltos.conf <<'EOF'
# CobaltOS installer settings
[Network]
default_on_boot = FIRST_WIRED_WITH_LINK

[Bootloader]
menu_auto_hide = True

[Storage]
default_scheme = BTRFS
btrfs_compression = zstd:1

[User Interface]
hidden_spokes =
    NetworkSpoke
    PasswordSpoke
hidden_webui_pages =
    root-password
    network

[Localization]
use_geolocation = False

[Payload]
flatpak_remote = flathub https://dl.flathub.org/repo/
EOF

# Installer branding: "Install CobaltOS" launcher with the CobaltOS logo
LOGO_SVG=/usr/share/icons/hicolor/scalable/apps/cobaltos.svg
for f in /usr/share/icons/hicolor/*/apps/org.fedoraproject.AnacondaInstaller.svg \
         /usr/share/icons/hicolor/*/apps/anaconda.svg; do
    if [ -e "$f" ]; then cp --remove-destination "$LOGO_SVG" "$f"; fi
done
for f in /usr/share/applications/liveinst.desktop /usr/share/applications/org.fedoraproject.AnacondaInstaller.desktop; do
    [ -f "$f" ] || continue
    sed -i -e 's/^Name=.*/Name=Install CobaltOS/' -e '/^Name\[/d' \
           -e 's/^GenericName=.*/GenericName=Install CobaltOS to your computer/' -e '/^GenericName\[/d' "$f"
done
# GTK installer artwork, if present
PIX=/usr/share/anaconda/pixmaps
if [ -d "$PIX" ]; then
    for f in sidebar-logo.png anaconda_header.png; do
        if [ -f "$PIX/$f" ]; then rsvg-convert -h 128 -o "$PIX/$f" /usr/share/cobaltos/artwork/splash-logo.svg; fi
    done
    for f in sidebar-bg.png topbar-bg.png; do
        if [ -f "$PIX/$f" ]; then rsvg-convert -w 1920 -h 1080 -o "$PIX/$f" /usr/share/cobaltos/artwork/wallpaper.svg; fi
    done
fi

# The install itself: CobaltOS from the copy on the USB stick, then the apps.
mkdir -p /usr/share/anaconda/post-scripts
cat >> /usr/share/anaconda/interactive-defaults.ks <<EOF

ostreecontainer --url=$IMAGE_REF:$IMAGE_TAG --transport=containers-storage --no-signature-verification
%include /usr/share/anaconda/post-scripts/cobaltos-updates.ks
%include /usr/share/anaconda/post-scripts/cobaltos-flatpaks.ks
%include /usr/share/anaconda/post-scripts/cobaltos-secureboot.ks
EOF

# Future updates come signed from GitHub, not from the USB copy
cat > /usr/share/anaconda/post-scripts/cobaltos-updates.ks <<EOF
%post --erroronfail --log=/tmp/cobaltos-updates.log
sed -i 's|container-image-reference=.*|container-image-reference=ostree-image-signed:docker://$IMAGE_REF:$IMAGE_TAG|' /ostree/deploy/default/deploy/*.origin
systemctl disable flatpak-add-fedora-repos.service || :
%end
EOF

cat > /usr/share/anaconda/post-scripts/cobaltos-flatpaks.ks <<'EOF'
%post --erroronfail --nochroot --log=/tmp/cobaltos-flatpaks.log
deployment="$(ostree rev-parse --repo=/mnt/sysimage/ostree/repo ostree/0/1/0)"
target="/mnt/sysimage/ostree/deploy/default/deploy/$deployment.0/var/lib/"
mkdir -p "$target"
rsync -aAXUHKP --filter='-x security.selinux' /var/lib/flatpak "$target"
%end
EOF

# NVIDIA edition: queue Universal Blue's driver signing key for Secure Boot
SB_KEY=/usr/share/cobaltos/ublue-akmods-key.der
if [ -f /usr/share/cobaltos/live-nvidia ]; then
    curl --retry 3 -fLo "$SB_KEY" https://github.com/ublue-os/akmods/raw/main/certs/public_key.der
fi
cat > /usr/share/anaconda/post-scripts/cobaltos-secureboot.ks <<EOF
%post --nochroot --log=/tmp/cobaltos-secureboot.log
if [ -d /sys/firmware/efi ] && [ -f "$SB_KEY" ]; then
    mokutil --timeout -1 || :
    printf 'universalblue\nuniversalblue\n' | mokutil --import "$SB_KEY" || :
fi
%end
EOF

# --- Live session tweaks --------------------------------------------------------
# no updates or background setup while running from the USB stick
for s in rpm-ostree-countme.service rpm-ostreed-automatic.timer uupd.timer bootloader-update.service \
         system-flatpak-setup.timer system-flatpak-setup.service \
         ublue-system-setup.service ublue-guest-user.service; do
    systemctl disable "$s" 2>/dev/null || :
done
for s in user-flatpak-setup.timer user-flatpak-setup.service ublue-user-setup.service podman-auto-update.timer; do
    systemctl --global disable "$s" 2>/dev/null || :
done

# welcome dialog with an "Install CobaltOS" button instead of the Welcome Center
rm -f /etc/xdg/autostart/cobalt-welcome.desktop
install -m 755 /src/live-welcome /usr/libexec/cobaltos/live-welcome
mkdir -p /etc/skel/.config/autostart
cat > /etc/skel/.config/autostart/cobaltos-live-welcome.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=CobaltOS Live Welcome
Exec=/usr/libexec/cobaltos/live-welcome
Icon=cobaltos
EOF

# taskbar: browser, installer, file manager
sed -i '/<entry name="launchers" type="StringList">/,/<\/entry>/ s/<default>[^<]*<\/default>/<default>preferred:\/\/browser,applications:liveinst.desktop,preferred:\/\/filemanager<\/default>/' \
    /usr/share/plasma/plasmoids/org.kde.plasma.taskmanager/contents/config/main.xml || :

# no KDE Wallet password prompts in the live session
mkdir -p /etc/skel/.config
printf '[Wallet]\nEnabled=false\n' > /etc/skel/.config/kwalletrc

# --- ISO boot files ---------------------------------------------------------------
dnf install -y grub2-efi-x64-cdboot
mkdir -p /boot/efi
cp -av /usr/lib/efi/*/*/EFI /boot/efi/
cp -v /boot/efi/EFI/fedora/grubx64.efi /boot/efi/EFI/BOOT/fbx64.efi

rm -f /etc/localtime
systemd-firstboot --timezone UTC

# The live system's / is in RAM; give /var/tmp enough room for the installer
rm -rf /var/tmp
mkdir /var/tmp
cat > /etc/systemd/system/var-tmp.mount <<'EOF'
[Unit]
Description=Larger tmpfs for /var/tmp on live system

[Mount]
What=tmpfs
Where=/var/tmp
Type=tmpfs
Options=size=50%%,nr_inodes=1m,x-systemd.graceful-option=usrquota

[Install]
WantedBy=local-fs.target
EOF
systemctl enable var-tmp.mount

# keep the bundled apps untouched so they copy cleanly to the new system
cat > /etc/systemd/system/var-lib-flatpak.mount <<'EOF'
[Mount]
Type=none
What=/var/lib/flatpak
Where=/var/lib/flatpak
Options=bind,ro

[Install]
WantedBy=multi-user.target
EOF
systemctl enable var-lib-flatpak.mount

# systemd-tmpfiles fails to label the install target when /mnt is a symlink
rm -f /mnt
mkdir -p /mnt

mkdir -p /usr/lib/bootc-image-builder
cp /src/iso.yaml /usr/lib/bootc-image-builder/iso.yaml

dnf clean all
