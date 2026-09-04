#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$project_dir/.build"
app_dir="$project_dir/dist/Power Flow Lite.app"
contents_dir="$app_dir/Contents"
resources_dir="$contents_dir/Resources"
iconset_dir="$build_dir/PowerFlowLite.iconset"
base_icon="$build_dir/PowerFlowLite-1024.png"
powerflow_sdk="$(xcrun --sdk macosx --show-sdk-path)"

if [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ]]; then
    powerflow_sdk=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
fi

mkdir -p "$build_dir/cache" "$build_dir/config" "$build_dir/security" "$build_dir/clang-cache"
export SDKROOT="$powerflow_sdk"
export CLANG_MODULE_CACHE_PATH="$build_dir/clang-cache"

swift build --disable-sandbox --package-path "$project_dir" --scratch-path "$build_dir" --cache-path "$build_dir/cache" --config-path "$build_dir/config" --security-path "$build_dir/security" --product PowerFlowLite -c release

mkdir -p "$contents_dir/MacOS" "$resources_dir" "$iconset_dir"
install -m 755 "$build_dir/release/PowerFlowLite" "$contents_dir/MacOS/PowerFlowLite"
install -m 644 "$project_dir/App/Info.plist" "$contents_dir/Info.plist"

swift -sdk "$powerflow_sdk" "$project_dir/scripts/make_icon.swift" "$base_icon"
sips -z 16 16 "$base_icon" --out "$iconset_dir/icon_16x16.png" >/dev/null
sips -z 32 32 "$base_icon" --out "$iconset_dir/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$base_icon" --out "$iconset_dir/icon_32x32.png" >/dev/null
sips -z 64 64 "$base_icon" --out "$iconset_dir/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$base_icon" --out "$iconset_dir/icon_128x128.png" >/dev/null
sips -z 256 256 "$base_icon" --out "$iconset_dir/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$base_icon" --out "$iconset_dir/icon_256x256.png" >/dev/null
sips -z 512 512 "$base_icon" --out "$iconset_dir/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$base_icon" --out "$iconset_dir/icon_512x512.png" >/dev/null
install -m 644 "$base_icon" "$iconset_dir/icon_512x512@2x.png"
swift -sdk "$powerflow_sdk" "$project_dir/scripts/make_icns.swift" "$iconset_dir" "$resources_dir/AppIcon.icns"

codesign --force --deep --sign - "$app_dir"

echo "$app_dir"
