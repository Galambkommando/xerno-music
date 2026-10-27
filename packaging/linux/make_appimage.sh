#!/usr/bin/env bash
# Build an AppImage from a Flutter Linux bundle.
# Usage: packaging/linux/make_appimage.sh [bundle_dir] [version] [output_dir]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUNDLE="${1:-$ROOT/build/linux/x64/release/bundle}"
VERSION="${2:-1.0.0}"
OUT="${3:-$ROOT/dist}"
APPDIR="$OUT/XernoMusic.AppDir"

if [[ ! -x "$BUNDLE/xerno_music" ]]; then
  echo "Linux bundle not found at $BUNDLE" >&2
  exit 1
fi

rm -rf "$APPDIR"
mkdir -p "$APPDIR"
cp -a "$BUNDLE/." "$APPDIR/"

cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="$HERE/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
cd "$HERE"
exec "$HERE/xerno_music" "$@"
EOF
chmod +x "$APPDIR/AppRun"

sed 's/^Exec=.*/Exec=xerno_music/' \
  "$ROOT/packaging/linux/online.mucsarocsoge.xerno_music.desktop" \
  > "$APPDIR/online.mucsarocsoge.xerno_music.desktop"
cp "$ROOT/assets/icons/xerno.png" "$APPDIR/xerno-music.png"
cp "$ROOT/assets/icons/xerno.png" "$APPDIR/.DirIcon"

mkdir -p "$OUT"
TOOL="$OUT/appimagetool-x86_64.AppImage"
if [[ ! -x "$TOOL" ]]; then
  curl -fsSL -o "$TOOL" \
    "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
  chmod +x "$TOOL"
fi

export APPIMAGE_EXTRACT_AND_RUN=1
ARCH=x86_64 "$TOOL" "$APPDIR" "$OUT/XernoMusic-${VERSION}-linux-x86_64.AppImage"
echo "Wrote $OUT/XernoMusic-${VERSION}-linux-x86_64.AppImage"
