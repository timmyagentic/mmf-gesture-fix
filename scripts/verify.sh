#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
app_path="$project_dir/build/MMF Gesture Fix.app"
codesign --verify --deep --strict "$app_path"
plutil -lint "$app_path/Contents/Info.plist"
architectures="$(lipo -archs "$app_path/Contents/MacOS/MMFGestureFix")"
[[ " $architectures " == *" arm64 "* && " $architectures " == *" x86_64 "* ]]
for arch in arm64 x86_64; do
  xcrun clang -arch "$arch" -fobjc-arc -fmodules -mmacosx-version-min=13.0 \
    -Wall -Wextra -Werror --analyze "$project_dir/Sources/HIDBridge.m" -o "$project_dir/build/analyzer-$arch.plist"
done
if [[ "$(sw_vers -productVersion | cut -d. -f1)" == "27" ]]; then
  "$app_path/Contents/MacOS/MMFGestureFix" --self-test
else
  echo 'SKIP: private HID runtime self-test requires macOS 27'
fi
echo 'PASS: universal build, signature and bridge analysis; runtime self-test scope is reported above'
