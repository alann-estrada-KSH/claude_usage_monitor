#!/usr/bin/env bash
# Packages the already-built `flutter build linux --release` bundle into a
# .deb, for the apt repo published at
# https://alann-estrada-ksh.github.io/claude_usage_monitor/apt (see
# .github/workflows/release.yml). Run from the repo root:
#   packaging/linux/build_deb.sh <version>
set -euo pipefail

VERSION="${1:?usage: build_deb.sh <version, e.g. 1.1.0>}"
ARCH=amd64
PKG=claude-usage-monitor
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUNDLE_DIR="$ROOT_DIR/build/linux/x64/release/bundle"
STAGE="$ROOT_DIR/packaging/linux/stage/${PKG}_${VERSION}_${ARCH}"
OUT="$ROOT_DIR/${PKG}_${VERSION}_${ARCH}.deb"

if [ ! -d "$BUNDLE_DIR" ]; then
  echo "Missing $BUNDLE_DIR -- run 'flutter build linux --release' first." >&2
  exit 1
fi

rm -rf "$STAGE"
mkdir -p "$STAGE/DEBIAN" \
         "$STAGE/opt/$PKG" \
         "$STAGE/usr/bin" \
         "$STAGE/usr/share/applications" \
         "$STAGE/usr/share/icons/hicolor/512x512/apps"

cp -r "$BUNDLE_DIR"/. "$STAGE/opt/$PKG/"

cat > "$STAGE/usr/bin/$PKG" <<EOF
#!/bin/sh
exec /opt/$PKG/claude_usage_monitor "\$@"
EOF
chmod +x "$STAGE/usr/bin/$PKG"

cp "$ROOT_DIR/assets/icon/app_icon_512.png" "$STAGE/usr/share/icons/hicolor/512x512/apps/$PKG.png"
cp "$ROOT_DIR/packaging/linux/$PKG.desktop" "$STAGE/usr/share/applications/$PKG.desktop"

# Runtime deps mirror what this app actually links against on Linux: GTK3 +
# webkit2gtk (the login WebView) + ayatana-appindicator (the tray icon).
cat > "$STAGE/DEBIAN/control" <<EOF
Package: $PKG
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Maintainer: Alann Estrada <https://github.com/alannnn-estrada>
Depends: libgtk-3-0, libwebkit2gtk-4.1-0, libayatana-appindicator3-1
Description: Unofficial Claude.ai usage monitor
 Shows Claude.ai's 5-hour and weekly usage limits from the system tray.
 Unofficial, not affiliated with or endorsed by Anthropic.
EOF

dpkg-deb --root-owner-group --build "$STAGE" "$OUT"
echo "Built $OUT"
