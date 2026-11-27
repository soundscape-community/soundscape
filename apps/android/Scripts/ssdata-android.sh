#!/usr/bin/env bash
# Copyright (c) Soundscape Community Contributors.
# Licensed under the MIT License.

set -euo pipefail

if [[ $# -ne 1 || ( $1 != build && $1 != test ) ]]; then
    echo "Usage: $0 {build|test}" >&2
    exit 2
fi

operation=$1
android_dir=$(cd "$(dirname "$0")/.." && pwd)
build_dir="$android_dir/.build"
swift_version=${SWIFT_ANDROID_VERSION:-6.4.3}
arch=aarch64
api_level=28

: "${ANDROID_NDK_HOME:?Set ANDROID_NDK_HOME to the NDK matching the Swift Android SDK}"
ndk=$(cd "$ANDROID_NDK_HOME" && pwd -P)
export ANDROID_NDK_HOME="$ndk"
ndk_bins=("$ndk"/toolchains/llvm/prebuilt/*/bin)
if [[ ${#ndk_bins[@]} -ne 1 || ! -x ${ndk_bins[0]}/clang ]]; then
    echo "Could not locate the LLVM toolchain in $ndk" >&2
    exit 1
fi
ndk_bin=${ndk_bins[0]}
ndk_revision=$(sed -n 's/^Pkg.Revision *= *//p' "$ndk/source.properties")
: "${ndk_revision:?Could not determine the Android NDK revision}"

sqlite=sqlite-amalgamation-3540100
sqlite_sha256=0a9c8e34352dad46006aa82836d5383bff9dc6bc9ce5a60553c05aa30e6ad1f9
archive="$build_dir/$sqlite.zip"
sqlite_build="$build_dir/$sqlite-$arch-api$api_level-ndk$ndk_revision"

mkdir -p "$build_dir"
staging=$(mktemp -d "$build_dir/sqlite.XXXXXXXX")
trap 'rm -rf "$staging"' EXIT

if [[ ! -f $archive ]]; then
    curl --fail --silent --show-error --location --retry 3 \
        "https://www.sqlite.org/2026/$sqlite.zip" -o "$staging/$sqlite.zip"
    printf '%s  %s\n' "$sqlite_sha256" "$staging/$sqlite.zip" | shasum -a 256 -c
    mv -f "$staging/$sqlite.zip" "$archive"
else
    printf '%s  %s\n' "$sqlite_sha256" "$archive" | shasum -a 256 -c
fi

if [[ ! -f $sqlite_build/libsqlite3.a || ! -f $sqlite_build/sqlite3.h ]]; then
    unzip -q "$archive" "$sqlite/sqlite3.c" "$sqlite/sqlite3.h" -d "$staging"
    "$ndk_bin/clang" --target="$arch-linux-android$api_level" -O2 -fPIC \
        -DSQLITE_ENABLE_FTS5 -DSQLITE_ENABLE_SNAPSHOT \
        -c "$staging/$sqlite/sqlite3.c" -o "$staging/sqlite3.o"
    "$ndk_bin/llvm-ar" rcs "$staging/libsqlite3.a" "$staging/sqlite3.o"

    mkdir -p "$sqlite_build"
    mv -f "$staging/$sqlite/sqlite3.h" "$staging/libsqlite3.a" "$sqlite_build"
fi

# GRDB's system module imports <sqlite3.h> and autolinks -lsqlite3.
# Put our Android header and static library ahead of the SDK search paths.
args=(
    --package-path "$android_dir/../common"
    --scratch-path "$build_dir/ssdata" --swift-version "$swift_version" --ndk "$ndk"
    --arch "$arch" --android-api-level "$api_level" --no-bridge
    -Xcc "-I$sqlite_build" -Xlinker "-L$sqlite_build"
)
if [[ $operation == test ]]; then
    args+=(--testing-library xctest)
fi
skip android "$operation" "${args[@]}"
