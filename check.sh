#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/src/backend"

cargo fmt --check

for target in aarch64-unknown-linux-gnu armv7-unknown-linux-gnueabihf; do
  cargo check --target "$target" --all-targets --all-features
  cargo clippy --target "$target" --all-targets --all-features
  cargo test --target "$target" --all-targets --all-features --no-run
done
