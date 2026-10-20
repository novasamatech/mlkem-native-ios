#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")"

module_name="CMLKEMNative"
library_name="lib${module_name}.a"
upstream_url="https://github.com/novasamatech/mlkem-native.git"
upstream_commit="d1b2fe782888bdb761a50336012923180be7f502"
include_dir="include"
output_dir="xcframework"
build_dir="build"
upstream_dir="$build_dir/mlkem-native"
work_dir="$build_dir/work"
min_ios_version="16.0"
min_macos_version="12.0"

symbol_prefix="_NOVA_MLKEM768_"
api_symbols=(check_pk check_sk dec enc_derand keypair_derand)
randomized_symbols=(enc keypair)

cflags=(
    -std=c99
    -O3
    -fomit-frame-pointer
    -Wall
    -Wextra
    -Wpedantic
    -Werror
    -Werror=unused-result
    -Wmissing-prototypes
    -Wshadow
    -Wpointer-arith
    -Wconversion
    -Wsign-conversion
    -Wno-long-long
    -Wno-unknown-pragmas
    "-ffile-prefix-map=$PWD=."
    "-DMLK_CONFIG_FILE=\"mlkem_native_ios_config.h\""
    -DMLK_CHECK_APIS
)

log() {
    echo "[build] $*"
}

fail() {
    echo "[build] error: $*" >&2
    exit 1
}

for cmd in xcrun xcodebuild lipo nm shasum git python3; do
    command -v "$cmd" > /dev/null || fail "$cmd not found"
done

if [[ ! -e "$upstream_dir" ]]; then
    log "fetching $upstream_url at $upstream_commit"
    partial_dir="$upstream_dir.partial"
    rm -rf "$partial_dir"
    git init -q "$partial_dir"
    git -C "$partial_dir" remote add origin "$upstream_url"
    git -C "$partial_dir" fetch -q --depth 1 origin "$upstream_commit"
    git -C "$partial_dir" checkout -q --detach FETCH_HEAD
    mv "$partial_dir" "$upstream_dir"
fi

actual_commit="$(git -C "$upstream_dir" rev-parse HEAD 2> /dev/null || true)"
[[ "$actual_commit" == "$upstream_commit" ]] \
    || fail "$upstream_dir is at '${actual_commit}', expected $upstream_commit (delete it to fetch again)"
[[ -z "$(git -C "$upstream_dir" status --porcelain)" ]] || fail "$upstream_dir has local changes"

log "xcode: $(xcodebuild -version | tr '\n' ' ')"
log "clang: $(xcrun clang --version | head -1)"
log "upstream: $upstream_commit"

rm -rf "$work_dir" "$output_dir/$module_name.xcframework"
mkdir -p "$work_dir" "$output_dir"

headers_root="$work_dir/headers"
headers_dir="$headers_root/$module_name"
mkdir -p "$headers_dir"
cp "$include_dir/CMLKEMNative.h" "$include_dir/mlkem_native_ios_config.h" "$include_dir/module.modulemap" "$headers_dir/"
cp "$upstream_dir/mlkem/mlkem_native.h" "$headers_dir/"

export ZERO_AR_DATE=1

build_thin() {
    local sdk="$1" target="$2"
    local dir="$work_dir/$target"
    mkdir -p "$dir"

    log "compiling $target"
    xcrun --sdk "$sdk" clang \
        -target "$target" \
        -isysroot "$(xcrun --sdk "$sdk" --show-sdk-path)" \
        "${cflags[@]}" \
        -I "$headers_dir" \
        -c "$upstream_dir/mlkem/mlkem_native.c" \
        -o "$dir/mlkem_native.o"
    xcrun --sdk "$sdk" libtool -static -D -o "$dir/$library_name" "$dir/mlkem_native.o"

    local defined
    defined="$(nm -gUj "$dir/$library_name" | grep -v ':$' | grep -v '^$' | sort)"
    if grep -v "^$symbol_prefix" <<< "$defined"; then
        fail "$target exports symbols outside $symbol_prefix"
    fi
    for symbol in "${api_symbols[@]}"; do
        grep -qx "$symbol_prefix$symbol" <<< "$defined" || fail "$target misses $symbol_prefix$symbol"
    done
    for symbol in "${randomized_symbols[@]}"; do
        if grep -qx "$symbol_prefix$symbol" <<< "$defined"; then
            fail "$target exports the randomized $symbol_prefix$symbol"
        fi
    done
    if nm -uj "$dir/$library_name" | grep -qi 'randombytes'; then
        fail "$target references randombytes"
    fi
}

build_slice() {
    local slice="$1" sdk="$2"
    shift 2
    local thin=()
    for target in "$@"; do
        build_thin "$sdk" "$target"
        thin+=("$work_dir/$target/$library_name")
    done
    mkdir -p "$work_dir/$slice"
    lipo -create "${thin[@]}" -output "$work_dir/$slice/$library_name"
}

build_slice ios-arm64 iphoneos \
    "arm64-apple-ios${min_ios_version}"
build_slice ios-arm64_x86_64-simulator iphonesimulator \
    "arm64-apple-ios${min_ios_version}-simulator" \
    "x86_64-apple-ios${min_ios_version}-simulator"
build_slice macos-arm64_x86_64 macosx \
    "arm64-apple-macos${min_macos_version}" \
    "x86_64-apple-macos${min_macos_version}"

log "creating $module_name.xcframework"
xcodebuild -create-xcframework \
    -library "$work_dir/ios-arm64/$library_name" -headers "$headers_root" \
    -library "$work_dir/ios-arm64_x86_64-simulator/$library_name" -headers "$headers_root" \
    -library "$work_dir/macos-arm64_x86_64/$library_name" -headers "$headers_root" \
    -output "$output_dir/$module_name.xcframework" > /dev/null

python3 - "$output_dir/$module_name.xcframework/Info.plist" << 'EOF'
import plistlib
import sys

path = sys.argv[1]
with open(path, "rb") as file:
    info = plistlib.load(file)
info["AvailableLibraries"].sort(key=lambda library: library["LibraryIdentifier"])
with open(path, "wb") as file:
    plistlib.dump(info, file, sort_keys=True)
EOF

cp "$upstream_dir/LICENSE" "$output_dir/LICENSE-mlkem-native"

rm -rf "$work_dir"

log "sha256:"
(cd "$output_dir" && shasum -a 256 "$module_name.xcframework"/*/"$library_name")
