#!/usr/bin/env bash
# CobaltOS build-time setup: runs inside the image build (see common-gaming.yml).
set -oue pipefail

ART=/usr/share/cobaltos/artwork

# --- Welcome Center -------------------------------------------------------
# Files copied from the repo may lose their executable bit; make sure the
# welcome center can run.
chmod 755 /usr/bin/cobalt-welcome

# --- Wallpapers -----------------------------------------------------------
# Render the SVG artwork to PNGs as KDE wallpaper packages.
# make_wallpaper DIR-NAME SVG: the display name comes from the SVG's <title>.
make_wallpaper() {
    local dir=/usr/share/wallpapers/$1 svg=$2 name
    name=$(sed -n 's:.*<title>\(.*\)</title>.*:\1:p' "$svg" | head -n 1)
    mkdir -p "$dir/contents/images"
    for size in 1920x1080 2560x1440 3840x2160; do
        rsvg-convert -w "${size%x*}" -h "${size#*x}" -o "$dir/contents/images/$size.png" "$svg"
    done
    rsvg-convert -w 400 -h 225 -o "$dir/contents/screenshot.png" "$svg"
    cat > "$dir/metadata.json" <<EOF
{
    "KPlugin": {
        "Authors": [{ "Name": "CobaltOS" }],
        "Id": "$1",
        "Name": "${name:-$1}"
    }
}
EOF
}
# the default one, plus the extra CobaltOS wallpapers
make_wallpaper CobaltOS "$ART/wallpaper.svg"
for svg in "$ART"/wallpapers/*.svg; do
    make_wallpaper "CobaltOS-$(basename "$svg" .svg)" "$svg"
done

# Fedora's KDE settings point the desktop, lock screen and login screen at
# /usr/share/wallpapers/Default (and Fedora -> Default). Point it at ours.
cd /usr/share/wallpapers
if [ -e Default ] && [ ! -L Default ]; then
    mv Default Default.fedora
fi
ln -sfn CobaltOS Default
ls -l /usr/share/wallpapers

# --- Boot splash (Plymouth) -----------------------------------------------
# Reuse Fedora's spinner animation frames, add the CobaltOS logo.
THEME=/usr/share/plymouth/themes/cobaltos
SPINNER=/usr/share/plymouth/themes/spinner
if [ ! -d "$SPINNER" ]; then
    echo "Plymouth spinner theme not found at $SPINNER" >&2
    exit 1
fi
for f in "$SPINNER"/*.png; do
    name=$(basename "$f")
    [ "$name" = "watermark.png" ] && continue
    cp -n "$f" "$THEME/$name"
done
rsvg-convert -o "$THEME/watermark.png" "$ART/splash-logo.svg"
ls "$THEME" | head -5
# /etc/plymouth/plymouthd.conf selects the theme; the initramfs module in the
# recipe rebuilds the initramfs so it's used from the very start of boot.

# --- Icons ----------------------------------------------------------------
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f /usr/share/icons/hicolor || true
fi
