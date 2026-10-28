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

# Never ship the build machine's libmpv or its ffmpeg dependencies. Arch and
# CachyOS load /usr/lib/libmpv.so.2; a partial Ubuntu copy breaks the ABI.
find "$APPDIR" -name 'libmpv.so*' -delete

cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/sh
set -eu
HERE="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="$HERE/lib:/usr/lib:/usr/lib64:/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# media_kit dlopens libmpv.so, then libmpv.so.2, then libmpv.so.1. CachyOS
# often has only libmpv.so.2. Point the sonames at that file without bundling it.
mpv_real=""
for candidate in \
  /usr/lib/libmpv.so.2 \
  /usr/lib64/libmpv.so.2 \
  /usr/lib/x86_64-linux-gnu/libmpv.so.2 \
  /lib/x86_64-linux-gnu/libmpv.so.2
do
  if [ -e "$candidate" ]; then
    mpv_real=$candidate
    break
  fi
done

mpv_unversioned=""
for candidate in \
  /usr/lib/libmpv.so \
  /usr/lib64/libmpv.so \
  /usr/lib/x86_64-linux-gnu/libmpv.so \
  /lib/x86_64-linux-gnu/libmpv.so
do
  if [ -e "$candidate" ]; then
    mpv_unversioned=$candidate
    break
  fi
done

mpv_dir=""
if [ -n "$mpv_real" ]; then
  if [ -z "${LIBMPV_LIBRARY_PATH:-}" ]; then
    export LIBMPV_LIBRARY_PATH="$mpv_real"
  fi
  if [ -z "$mpv_unversioned" ]; then
    mpv_dir="/tmp/xerno-mpv-$$"
    if mkdir -p "$mpv_dir"; then
      ln -sfn "$mpv_real" "$mpv_dir/libmpv.so"
      ln -sfn "$mpv_real" "$mpv_dir/libmpv.so.1"
      ln -sfn "$mpv_real" "$mpv_dir/libmpv.so.2"
      export LD_LIBRARY_PATH="$mpv_dir:$LD_LIBRARY_PATH"
    else
      mpv_dir=""
    fi
  fi
fi

# GTK already prefers Wayland and falls back to X11. Set that order when the
# desktop has not chosen a backend. Do not force software GL; real GPUs should
# keep their driver.
if [ -z "${GDK_BACKEND:-}" ]; then
  export GDK_BACKEND="wayland,x11"
fi

cleanup() {
  if [ -n "$mpv_dir" ]; then
    rm -rf "$mpv_dir"
  fi
}
trap cleanup EXIT INT TERM

cd "$HERE"
set +e
"$HERE/xerno_music" "$@"
status=$?
set -e
exit "$status"
EOF
chmod +x "$APPDIR/AppRun"

sed 's/^Exec=.*/Exec=xerno_music/' \
  "$ROOT/packaging/linux/online.mucsarocsoge.xerno_music.desktop" \
  > "$APPDIR/online.mucsarocsoge.xerno_music.desktop"
cp "$ROOT/assets/icons/xerno.png" "$APPDIR/xerno-music.png"
cp "$ROOT/assets/icons/xerno.png" "$APPDIR/.DirIcon"

mkdir -p "$OUT"
rm -f "$OUT/appimagetool-x86_64.AppImage"
TOOL="${TMPDIR:-/tmp}/appimagetool-x86_64.AppImage"
if [[ ! -x "$TOOL" ]]; then
  curl -fsSL -o "$TOOL" \
    "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
  chmod +x "$TOOL"
fi

export APPIMAGE_EXTRACT_AND_RUN=1
ARCH=x86_64 "$TOOL" --appimage-extract-and-run "$APPDIR" \
  "$OUT/XernoMusic-${VERSION}-linux-x86_64.AppImage"
echo "Wrote $OUT/XernoMusic-${VERSION}-linux-x86_64.AppImage"
