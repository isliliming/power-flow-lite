#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$project_dir/.build"
powerflow_sdk="$(xcrun --sdk macosx --show-sdk-path)"

# Some macOS beta Command Line Tools ship a newer compiler beside a slightly
# older 26.x SDK. The 15.4 SDK remains compatible with the app's macOS 13 target.
if [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ]]; then
    powerflow_sdk=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
fi

mkdir -p "$build_dir/cache" "$build_dir/config" "$build_dir/security" "$build_dir/clang-cache"

export SDKROOT="$powerflow_sdk"
export CLANG_MODULE_CACHE_PATH="$build_dir/clang-cache"

swift run --disable-sandbox --package-path "$project_dir" --scratch-path "$build_dir" --cache-path "$build_dir/cache" --config-path "$build_dir/config" --security-path "$build_dir/security" PowerFlowChecks
