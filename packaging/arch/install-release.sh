#!/usr/bin/env bash
# Install a prebuilt Xerno Music Linux bundle on CachyOS / Arch.
# Usage: packaging/arch/install-release.sh XernoMusic-1.0.0-linux-x86_64.tar.gz
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 XernoMusic-linux-x86_64.tar.gz" >&2
  exit 1
fi

TARBALL="$(readlink -f "$1")"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PREFIX="${PREFIX:-/opt/xerno-music}"

if [[ "$(id -u)" -eq 0 ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

$SUDO install -dm755 "$PREFIX"
$SUDO tar -xzf "$TARBALL" -C "$PREFIX"
$SUDO ln -sfn "$PREFIX/xerno_music" /usr/bin/xerno-music
$SUDO install -Dm644 "$ROOT/packaging/linux/online.mucsarocsoge.xerno_music.desktop" \
  /usr/share/applications/online.mucsarocsoge.xerno_music.desktop
$SUDO install -Dm644 "$ROOT/assets/icons/xerno.png" \
  /usr/share/icons/hicolor/1024x1024/apps/xerno-music.png
$SUDO gtk-update-icon-cache -f /usr/share/icons/hicolor >/dev/null 2>&1 || true
echo "Installed xerno-music from $TARBALL"
