#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$project_dir/build"
app_path="$build_dir/MMF Gesture Fix.app"
sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
identity="${MMF_GESTURE_SIGNING_IDENTITY:--}"
mkdir -p "$app_path/Contents/MacOS"
cp "$project_dir/Resources/Info.plist" "$app_path/Contents/Info.plist"
for arch in arm64 x86_64; do
  xcrun clang -arch "$arch" -fobjc-arc -fmodules -mmacosx-version-min=13.0 \
    -Wall -Wextra -Werror -c "$project_dir/Sources/HIDBridge.m" -o "$build_dir/bridge-$arch.o"
  xcrun swiftc -swift-version 5 -O -warnings-as-errors -parse-as-library \
    -target "$arch-apple-macosx13.0" -sdk "$sdk_path" \
    -import-objc-header "$project_dir/Sources/HIDBridge.h" \
    "$project_dir"/Sources/*.swift "$build_dir/bridge-$arch.o" \
    -framework AppKit -framework ApplicationServices -framework CoreGraphics -framework Security \
    -o "$build_dir/MMFGestureFix-$arch"
done
xcrun lipo -create "$build_dir/MMFGestureFix-arm64" "$build_dir/MMFGestureFix-x86_64" \
  -output "$app_path/Contents/MacOS/MMFGestureFix"
timestamp=(--timestamp)
if [[ "$identity" == "-" ]]; then timestamp=(--timestamp=none); fi
codesign --force --sign "$identity" --options runtime "${timestamp[@]}" "$app_path"
codesign --verify --deep --strict "$app_path"
if [[ "$(sw_vers -productVersion | cut -d. -f1)" == "27" ]]; then
  "$app_path/Contents/MacOS/MMFGestureFix" --self-test
else
  echo 'SKIP: private HID runtime self-test requires macOS 27; build is not runtime validation'
fi
printf 'Built: %s\n' "$app_path"
