#!/bin/sh
set -eu

APP_NAME="Syncthing for reMarkable"
REPO="paviro/Syncthing-for-reMarkable"
APPLOAD_ROOT="/home/root/xovi/exthome/appload"
DEST_DIR="$APPLOAD_ROOT/syncthing"
VELLUM_BOOTSTRAP_URL="https://github.com/vellum-dev/vellum-cli/releases/latest/download/bootstrap.sh"

say() {
    printf '%s\n' "$*"
}

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

confirm() {
    prompt="$1"
    printf '%s [y/N] ' "$prompt"
    read -r answer
    case "$answer" in
        y|Y|yes|YES) return 0 ;;
        *) fail "aborted" ;;
    esac
}

need_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        fail "$1 is required but was not found"
    fi
}

download() {
    url="$1"
    output="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fL "$url" -o "$output" && return 0
    fi

    if command -v wget >/dev/null 2>&1; then
        wget -O "$output" "$url" && return 0
        wget --no-check-certificate -O "$output" "$url" && return 0
    fi

    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        fail "curl or wget is required to download files"
    fi

    fail "failed to download $url"
}

ensure_vellum_on_path() {
    if command -v vellum >/dev/null 2>&1; then
        return 0
    fi

    if [ -x /home/root/.vellum/bin/vellum ]; then
        PATH="/home/root/.vellum/bin:$PATH"
        export PATH
        return 0
    fi

    return 1
}

cleanup() {
    if [ -n "${TMP_DIR:-}" ] && [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}

trap cleanup EXIT INT TERM

if [ "$(id -u)" != "0" ]; then
    fail "run this script as root on the reMarkable tablet"
fi

need_command uname
need_command unzip
need_command find
need_command cp

case "$(uname -m)" in
    aarch64)
        ASSET_NAME="syncthing-rm-appload-aarch64.zip"
        ;;
    armv7l|armv7*|arm*)
        ASSET_NAME="syncthing-rm-appload-armv7.zip"
        ;;
    *)
        fail "unsupported architecture: $(uname -m)"
        ;;
esac

DOWNLOAD_URL="https://github.com/$REPO/releases/latest/download/$ASSET_NAME"
TMP_DIR="$(mktemp -d)"
ARCHIVE="$TMP_DIR/$ASSET_NAME"
EXTRACT_DIR="$TMP_DIR/extract"
STAGE_DIR="$APPLOAD_ROOT/.syncthing-install.$$"
OLD_DIR="$APPLOAD_ROOT/.syncthing-old.$$"

say "$APP_NAME installer"
say
say "This script will:"
if ensure_vellum_on_path; then
    say "  - use the existing Vellum installation"
else
    say "  - install Vellum"
fi
say "  - install or update AppLoad with Vellum"
say "  - download $ASSET_NAME from the latest $REPO release"
if [ -d "$DEST_DIR" ]; then
    say "  - update the existing app at $DEST_DIR"
    say "  - preserve the installed Syncthing binary and local app config if present"
else
    say "  - install the app to $DEST_DIR"
fi
say
confirm "Continue?"

if ensure_vellum_on_path; then
    say "Vellum is already installed."
else
    say "Installing Vellum..."
    need_command bash
    need_command wget
    BOOTSTRAP="$TMP_DIR/vellum-bootstrap.sh"
    download "$VELLUM_BOOTSTRAP_URL" "$BOOTSTRAP"
    bash "$BOOTSTRAP"
fi

if ! ensure_vellum_on_path; then
    fail "Vellum installation completed but vellum is still not available on PATH"
fi

say "Installing AppLoad with Vellum..."
vellum update
vellum add appload

if [ -x /home/root/xovi/rebuild_hashtable ]; then
    say "Rebuilding XOVI hash table..."
    if ! /home/root/xovi/rebuild_hashtable; then
        say "Warning: XOVI hash table rebuild failed. You may need to run /home/root/xovi/rebuild_hashtable manually."
    fi
else
    say "Skipping XOVI hash table rebuild; /home/root/xovi/rebuild_hashtable was not found."
fi

if [ -x /home/root/xovi/start ]; then
    say "Starting XOVI/AppLoad..."
    if ! /home/root/xovi/start; then
        say "Warning: XOVI/AppLoad did not start. It may already be running, or you may need to run /home/root/xovi/start manually."
    fi
else
    say "Skipping XOVI start; /home/root/xovi/start was not found."
fi

say "Downloading latest $APP_NAME release..."
download "$DOWNLOAD_URL" "$ARCHIVE"

mkdir -p "$EXTRACT_DIR"
unzip -q "$ARCHIVE" -d "$EXTRACT_DIR"

PACKAGE_DIR="$(find "$EXTRACT_DIR" -mindepth 1 -maxdepth 1 -type d | sed -n '1p')"
PACKAGE_DIR_COUNT="$(find "$EXTRACT_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"

if [ "$PACKAGE_DIR_COUNT" != "1" ] || [ -z "$PACKAGE_DIR" ]; then
    fail "release archive must contain exactly one top-level app directory"
fi

[ -f "$PACKAGE_DIR/manifest.json" ] || fail "release archive is missing manifest.json"
[ -f "$PACKAGE_DIR/icon.png" ] || fail "release archive is missing icon.png"
[ -f "$PACKAGE_DIR/resources.rcc" ] || fail "release archive is missing resources.rcc"
[ -x "$PACKAGE_DIR/backend/entry" ] || fail "release archive is missing executable backend/entry"

mkdir -p "$APPLOAD_ROOT"
rm -rf "$STAGE_DIR"
rm -rf "$OLD_DIR"
mv "$PACKAGE_DIR" "$STAGE_DIR"

if [ -d "$DEST_DIR" ]; then
    say "Existing app install detected; preserving local Syncthing files before updating..."
    if [ -f "$DEST_DIR/syncthing" ]; then
        cp -p "$DEST_DIR/syncthing" "$STAGE_DIR/syncthing"
        say "Preserved installed Syncthing binary."
    fi
    if [ -f "$DEST_DIR/config.json" ]; then
        cp -p "$DEST_DIR/config.json" "$STAGE_DIR/config.json"
        say "Preserved local app config."
    fi

    say "Removing old app files..."
    mv "$DEST_DIR" "$OLD_DIR"
fi

if mv "$STAGE_DIR" "$DEST_DIR"; then
    rm -rf "$OLD_DIR"
    say "Installed $APP_NAME to $DEST_DIR."
else
    if [ -d "$OLD_DIR" ] && [ ! -d "$DEST_DIR" ]; then
        mv "$OLD_DIR" "$DEST_DIR"
    fi
    fail "failed to install app"
fi

say
say "Done. Open the sidebar on your reMarkable, tap AppLoad, then launch Syncthing."
say "When the app opens, it can download and install the Syncthing service."
