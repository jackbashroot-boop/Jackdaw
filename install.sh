#!/bin/sh
# Jackdaw installer for macOS and Linux.
#   curl -fsSL https://raw.githubusercontent.com/jackbashroot-boop/Jackdaw/main/install.sh | sh
set -eu

REPO="jackbashroot-boop/Jackdaw"
BASE="https://github.com/$REPO/releases"
BIN="jackdaw"

VERSION=""
UNINSTALL=0

say()  { printf '%s\n' "$*"; }
info() { printf '  %s\n' "$*"; }
die()  { printf 'jackdaw: %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --version)   [ $# -ge 2 ] || die "--version needs a value"; VERSION="${2#v}"; shift 2 ;;
    --uninstall) UNINSTALL=1; shift ;;
    -h|--help)
      say "Usage: install.sh [--version X.Y.Z] [--uninstall]"
      say ""
      say "  JACKDAW_HOME     install root (default ~/.local/share/jackdaw)"
      say "  JACKDAW_BIN_DIR  where the launcher goes (default ~/.local/bin)"
      exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

HOME_DIR="${JACKDAW_HOME:-$HOME/.local/share/jackdaw}"
BIN_DIR="${JACKDAW_BIN_DIR:-$HOME/.local/bin}"

if [ "$UNINSTALL" = 1 ]; then
  [ -L "$BIN_DIR/$BIN" ] && rm -f "$BIN_DIR/$BIN"
  rm -rf "$HOME_DIR"
  say "jackdaw uninstalled."
  case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) info "$BIN_DIR is still on your PATH; you can remove it by hand." ;;
  esac
  exit 0
fi

case "$(uname -s)" in
  Linux)  os_part=linux ;;
  Darwin) os_part=osx ;;
  *) die "unsupported OS: $(uname -s)" ;;
esac

case "$(uname -m)" in
  x86_64|amd64)  arch_part=x64 ;;
  arm64|aarch64) arch_part=arm64 ;;
  *) die "unsupported architecture: $(uname -m)" ;;
esac

rid="$os_part-$arch_part"
asset="$BIN-$rid.tar.gz"

if [ -n "$VERSION" ]; then
  url="$BASE/download/v$VERSION/$asset"
else
  url="$BASE/latest/download/$asset"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM

say "Downloading $asset"
curl -fsSL "$url"        -o "$tmp/$asset"        || die "could not download $url"
curl -fsSL "$url.sha256" -o "$tmp/$asset.sha256" || die "could not download the checksum"

say "Verifying checksum"
( cd "$tmp" && if command -v sha256sum >/dev/null 2>&1; then
      sha256sum -c "$asset.sha256"
    else
      shasum -a 256 -c "$asset.sha256"
    fi ) || die "checksum mismatch; refusing to install"

mkdir -p "$HOME_DIR" "$BIN_DIR"
rm -rf "$HOME_DIR/current.tmp"
mkdir -p "$HOME_DIR/current.tmp"
tar -xzf "$tmp/$asset" -C "$HOME_DIR/current.tmp"

[ -f "$HOME_DIR/current.tmp/$BIN" ] || die "archive did not contain $BIN"
chmod +x "$HOME_DIR/current.tmp/$BIN"

rm -rf "$HOME_DIR/previous"
[ -d "$HOME_DIR/current" ] && mv "$HOME_DIR/current" "$HOME_DIR/previous"
mv "$HOME_DIR/current.tmp" "$HOME_DIR/current"

ln -sfn "$HOME_DIR/current/$BIN" "$BIN_DIR/$BIN"

say ""
say "Installed to $BIN_DIR/$BIN"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    say ""
    say "Add this to your shell profile, then restart your shell:"
    info "export PATH=\"$BIN_DIR:\$PATH\"" ;;
esac
