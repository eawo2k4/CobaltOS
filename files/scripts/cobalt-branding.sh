#!/usr/bin/env bash
# CobaltOS branding: runs inside the image build after cobalt-setup.sh.
# Renames the system, adds the CobaltOS colour scheme, global theme and login
# splash, and swaps distro logos for the CobaltOS logo.
set -oue pipefail

ART=/usr/share/cobaltos/artwork
LIB=/usr/libexec/cobaltos
LOGO_SVG=/usr/share/icons/hicolor/scalable/apps/cobaltos.svg
REPO_URL=https://github.com/eawo2k4/CobaltOS
chmod 755 "$LIB/kconf-set" "$LIB/make-colorscheme"
KSET="$LIB/kconf-set"

# --- System name (os-release) ---------------------------------------------
# Shown in the boot menu, the text login, KDE's About page and fastfetch.
# ID stays "fedora" on purpose: dnf, Flatpak, toolbox and the ISO builder use
# it to know which Fedora this is built on.
OSR=/usr/lib/os-release
REAL=$(readlink -f "$OSR")
if [ "$REAL" != "$OSR" ]; then
    # /usr/lib/os-release is a symlink into os.release.d; make it our own file
    cp --remove-destination "$REAL" "$OSR"
fi
VERSION_ID=$(. "$OSR"; echo "$VERSION_ID")

set_osr() {
    if grep -q "^$1=" "$OSR"; then
        sed -i "s|^$1=.*|$1=\"$2\"|" "$OSR"
    else
        echo "$1=\"$2\"" >> "$OSR"
    fi
}
set_osr NAME "CobaltOS"
set_osr PRETTY_NAME "CobaltOS $VERSION_ID"
set_osr VARIANT "Your old PC games, on modern hardware"
set_osr LOGO "cobaltos"
set_osr ANSI_COLOR "0;38;2;37;99;235"
set_osr DEFAULT_HOSTNAME "cobaltos"
set_osr HOME_URL "$REPO_URL"
set_osr DOCUMENTATION_URL "$REPO_URL#readme"
set_osr SUPPORT_URL "$REPO_URL/issues"
set_osr BUG_REPORT_URL "$REPO_URL/issues"
echo "--- os-release ---"
cat "$OSR"

# --- Colour scheme ----------------------------------------------------------
# Breeze Dark, tinted cobalt navy with CobaltOS blue highlights.
SCHEMES=/usr/share/color-schemes
if [ ! -f "$SCHEMES/BreezeDark.colors" ]; then
    echo "Breeze Dark colour scheme not found in $SCHEMES" >&2
    exit 1
fi
"$LIB/make-colorscheme" "$SCHEMES/BreezeDark.colors" "$SCHEMES/CobaltOS.colors"

# --- Global theme -------------------------------------------------------------
# A copy of the distro's default Plasma global theme (panel layout etc.) with
# the CobaltOS colours and splash screen.
LNF=/usr/share/plasma/look-and-feel
echo "Global themes available: $(ls "$LNF" | tr '\n' ' ')"
CURRENT=""
if [ -f /etc/xdg/kdeglobals ]; then
    CURRENT=$(awk -F= '/^\[/{g=$0} g=="[KDE]" && $1=="LookAndFeelPackage"{print $2; exit}' /etc/xdg/kdeglobals)
fi
BASE=""
for cand in "$CURRENT" org.fedoraproject.fedora.desktop org.kde.breeze.desktop; do
    if [ -n "$cand" ] && [ -d "$LNF/$cand" ]; then
        BASE=$cand
        break
    fi
done
if [ -z "$BASE" ]; then
    echo "No base Plasma global theme found in $LNF" >&2
    exit 1
fi
echo "Basing the CobaltOS global theme on $BASE"
THEME_ID=org.cobaltos.desktop
THEME="$LNF/$THEME_ID"
rm -rf "$THEME"
cp -a "$LNF/$BASE" "$THEME"
rm -f "$THEME/metadata.desktop"

python3 - "$THEME/metadata.json" "$THEME_ID" "$REPO_URL" <<'EOF'
import json, os, sys
path, theme_id, url = sys.argv[1:]
data = {"KPackageStructure": "Plasma/LookAndFeel"}
if os.path.exists(path):
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
plugin = data.setdefault("KPlugin", {})
for key in list(plugin):
    if key.startswith(("Name[", "Description[")):
        del plugin[key]  # translated names of the base theme
plugin.update({
    "Id": theme_id,
    "Name": "CobaltOS",
    "Description": "The CobaltOS desktop theme",
    "Authors": [{"Name": "CobaltOS"}],
    "Website": url,
})
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=4)
EOF

DEFAULTS="$THEME/contents/defaults"
"$KSET" "$DEFAULTS" "kdeglobals][General" ColorScheme CobaltOS
"$KSET" "$DEFAULTS" "ksplashrc][KSplash" Engine KSplashQML
"$KSET" "$DEFAULTS" "ksplashrc][KSplash" Theme "$THEME_ID"

# login splash
rm -rf "$THEME/contents/splash"
mkdir -p "$THEME/contents/splash/images"
cp /usr/share/cobaltos/splash/Splash.qml "$THEME/contents/splash/Splash.qml"
rsvg-convert -w 1520 -h 400 -o "$THEME/contents/splash/images/logo.png" "$ART/splash-logo.svg"

# previews shown in System Settings (Qt reads them by content, whatever the extension)
if [ -d "$THEME/contents/previews" ]; then
    for f in "$THEME/contents/previews"/*; do
        case "$f" in
            *fullscreen*) rsvg-convert -w 1920 -h 1080 -o "$f" "$ART/wallpaper.svg" ;;
            *.png|*.jpg) rsvg-convert -w 800 -h 450 -o "$f" "$ART/wallpaper.svg" ;;
        esac
    done
fi

# Make it the default for everyone. Users can still change it in System Settings.
"$KSET" /etc/xdg/kdeglobals KDE LookAndFeelPackage "$THEME_ID"
"$KSET" /etc/xdg/kdeglobals General ColorScheme CobaltOS
# also write the colours themselves, for apps that read them before the theme applies
awk -F= '
    /^\[/ { g = substr($0, 2, length($0) - 2); next }
    (g ~ /^Colors:/ || g == "WM") && NF >= 2 { k = $1; sub(/^[^=]*=/, ""); print g "\t" k "\t" $0 }
' "$SCHEMES/CobaltOS.colors" | while IFS=$'\t' read -r group key value; do
    "$KSET" /etc/xdg/kdeglobals "$group" "$key" "$value"
done
"$KSET" /etc/xdg/ksplashrc KSplash Engine KSplashQML
"$KSET" /etc/xdg/ksplashrc KSplash Theme "$THEME_ID"
echo "--- global theme defaults ---"
cat "$DEFAULTS"

# --- Logos --------------------------------------------------------------------
# Replace distro logos (app menu button, "About" pages...) with the CobaltOS logo.
count=0
while IFS= read -r -d '' f; do
    case "$f" in
        *.svg)
            rm -f "$f"
            cp "$LOGO_SVG" "$f"
            ;;
        *.svgz)
            rm -f "$f"
            gzip -c "$LOGO_SVG" > "$f"
            ;;
        *.png)
            size=256
            scale=1
            if [[ "$f" =~ /([0-9]+)(x[0-9]+)?(@([0-9])x)?/ ]]; then
                size=${BASH_REMATCH[1]}
                scale=${BASH_REMATCH[4]:-1}
            fi
            px=$((size * scale))
            rm -f "$f"
            rsvg-convert -w "$px" -h "$px" -o "$f" "$LOGO_SVG"
            ;;
    esac
    count=$((count + 1))
done < <(find /usr/share/icons \
    \( -name 'start-here*' -o -name 'distributor-logo*' -o -name 'fedora-logo-icon*' -o -name 'system-logo-icon*' \) \
    ! -name '*symbolic*' \( -name '*.svg' -o -name '*.svgz' -o -name '*.png' \) -print0)
echo "Replaced $count distro logo icons with the CobaltOS logo"

for dir in /usr/share/icons/*/; do
    if [ -f "$dir/icon-theme.cache" ]; then
        gtk-update-icon-cache -f "$dir" >/dev/null 2>&1 || true
    fi
done
