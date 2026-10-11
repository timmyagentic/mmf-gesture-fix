#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$project_dir/build"
xcrun swiftc -swift-version 5 -warnings-as-errors \
  "$project_dir/Sources/GesturePolicy.swift" "$project_dir/Sources/SelfTest.swift" \
  "$project_dir/Sources/Language.swift" "$project_dir/Tests/LanguageTests.swift" \
  "$project_dir/Tests/main.swift" -o "$project_dir/build/PolicyTests"
"$project_dir/build/PolicyTests"
