#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RELEASE_DIR="$SCRIPT_DIR/target/release"
ARCH_TARGETS=(
    "aarch64:aarch64-unknown-linux-gnu"
    "armv7:armv7-unknown-linux-gnueabihf"
)

QT_BIN_DIR="${QT_BIN_DIR:-$(command -v qtpaths >/dev/null 2>&1 && qtpaths --binaries-dir || true)}"

if [[ -n "${QT_BIN_DIR:-}" && -x "$QT_BIN_DIR/rcc" ]]; then
    RCC_BIN="$QT_BIN_DIR/rcc"
elif [[ -x "/opt/homebrew/opt/qt/bin/rcc" ]]; then
    RCC_BIN="/opt/homebrew/opt/qt/bin/rcc"
elif [[ -x "/opt/homebrew/opt/qt@5/bin/rcc" ]]; then
    RCC_BIN="/opt/homebrew/opt/qt@5/bin/rcc"
elif command -v rcc >/dev/null 2>&1; then
    RCC_BIN="$(command -v rcc)"
else
    echo "error: Qt rcc not found. Install Qt and ensure qtpaths/rcc are on PATH (or set QT_BIN_DIR)." >&2
    exit 1
fi

if ! command -v zip >/dev/null 2>&1; then
    echo "error: zip not found. Install the zip utility to continue." >&2
    exit 1
fi

if ! command -v rustup >/dev/null 2>&1; then
    echo "error: rustup not found. Install Rust via rustup to continue." >&2
    exit 1
fi

build_arch() {
    local arch_label="$1"
    local target_triple="$2"

    local output_dir="$SCRIPT_DIR/target/syncthing-$arch_label"
    local package_name="syncthing-rm-appload-$arch_label.zip"
    local package_path="$RELEASE_DIR/$package_name"

    rm -rf "$output_dir"
    mkdir -p "$output_dir/backend"

    cp "$SCRIPT_DIR/src/manifest.json" "$output_dir/"
    cp "$SCRIPT_DIR/src/icon.png" "$output_dir/"
    cp "$SCRIPT_DIR/src/config.sample.json" "$output_dir/"

    "$RCC_BIN" --binary -o "$output_dir/resources.rcc" "$SCRIPT_DIR/src/application.qrc"

    rustup target add "$target_triple" >/dev/null

    (cd "$SCRIPT_DIR/src/backend" && cargo build --release --target "$target_triple" --message-format=short)
    cp "$SCRIPT_DIR/src/backend/target/$target_triple/release/syncthing-monitor-backend" "$output_dir/backend/entry"

    mkdir -p "$RELEASE_DIR"
    rm -f "$package_path"

    local output_parent
    output_parent="$(dirname "$output_dir")"
    local output_basename
    output_basename="$(basename "$output_dir")"

    (cd "$output_parent" && zip -r "$package_path" "$output_basename" >/dev/null)

    echo "Built $arch_label artifact in $output_dir"
    echo "Packaged archive available at $package_path"
}

for config in "${ARCH_TARGETS[@]}"; do
    arch_label="${config%%:*}"
    target_triple="${config#*:}"
    build_arch "$arch_label" "$target_triple"
done

echo "All builds completed."
