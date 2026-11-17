#!/usr/bin/env bash
# CobaltOS build-time setup: runs inside the image build (see common-gaming.yml).
set -oue pipefail

# Files copied from the repo may lose their executable bit; make sure the
# welcome center can run.
chmod 755 /usr/bin/cobalt-welcome

# Refresh the icon cache so the CobaltOS logo shows up everywhere.
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f /usr/share/icons/hicolor || true
fi
