#!/bin/bash
# Build the pinned embedded runtime; all generated files stay in Herdr/build.
set -euo pipefail
root=$(cd "$(dirname "$0")" && pwd)
source_root="$root/build/source"
target=${1:-aarch64-apple-ios-sim}
revision=7b116c05bfda646af39d2524c54e70c751f57ee8
case "$target" in
aarch64-apple-ios-sim | aarch64-apple-ios) ;;
*)
	echo "usage: $0 [aarch64-apple-ios-sim|aarch64-apple-ios]" >&2
	exit 2
	;;
esac
command -v cargo >/dev/null
command -v git >/dev/null
command -v "${ZIG:-zig}" >/dev/null
if [ -L "$root/build" ] || [ -L "$source_root" ]; then
	echo "Herdr build directories must not be symbolic links" >&2
	exit 2
fi
mkdir -p "$root/build"
if [ ! -d "$source_root/.git" ]; then
	git clone --depth 1 --branch v0.9.3 https://github.com/herdrdev/herdr.git "$source_root"
fi
if [ "$(git -C "$source_root" remote get-url origin)" != https://github.com/herdrdev/herdr.git ]; then
	echo "unexpected origin in the generated Herdr checkout" >&2
	exit 2
fi
if [ "$(git -C "$source_root" rev-parse HEAD)" != "$revision" ]; then
	echo "Herdr v0.9.3 does not match the pinned source revision" >&2
	exit 2
fi
# This checkout contains only generated build inputs. Keep user repositories out.
git -C "$source_root" reset --hard --quiet "$revision"
git -C "$source_root" clean -fdq
git -C "$source_root" apply "$root/native/platform.patch"
git -C "$source_root" apply "$root/native/entry.patch"
git -C "$source_root" apply --unidiff-zero "$root/native/runtime.patch"
git -C "$source_root" apply "$root/native/input-startup.patch"
cp "$root/native/ios_entry.rs" "$source_root/src/ios_entry.rs"
cp "$root/native/host_io.rs" "$source_root/src/host_io.rs"
cp "$root/native/ios_ipc.rs" "$source_root/src/ios_ipc.rs"
cp "$root/native/ios_pty.rs" "$source_root/src/pty/ios.rs"
export CARGO_TARGET_DIR="$root/build/target"
export ZIG_GLOBAL_CACHE_DIR="${ZIG_GLOBAL_CACHE_DIR:-$root/build/zig-cache}"
export LIBGHOSTTY_VT_SIMD=false LIBGHOSTTY_VT_OPTIMIZE=ReleaseSmall
(
	cd "$source_root"
	cargo +1.96.1 build --locked --release --lib --target "$target"
)
shasum -a 256 "$CARGO_TARGET_DIR/$target/release/libherdr_ios.a"
