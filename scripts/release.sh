#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -n "$(git -C "$project_dir" status --porcelain=v1)" ]]; then
  echo 'Commit the source candidate before packaging a public release.' >&2
  exit 1
fi
: "${MMF_GESTURE_SIGNING_IDENTITY:?Set a Developer ID Application identity}"
: "${MMF_GESTURE_NOTARY_PROFILE:?Set a stored notarytool Keychain profile}"
if [[ "$MMF_GESTURE_SIGNING_IDENTITY" == "-" ]]; then
  echo 'Public releases require Developer ID signing, not ad-hoc signing.' >&2
  exit 1
fi
"$project_dir/scripts/test.sh"
"$project_dir/scripts/build.sh"
"$project_dir/scripts/verify.sh"
app_path="$project_dir/build/MMF Gesture Fix.app"
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app_path/Contents/Info.plist")
dist="$project_dir/dist"
archive="MMF-Gesture-Fix-$version.app.zip"
mkdir -p "$dist"
ditto -c -k --keepParent "$app_path" "$dist/$archive"
xcrun notarytool submit "$dist/$archive" --keychain-profile "$MMF_GESTURE_NOTARY_PROFILE" \
  --wait --output-format json > "$dist/notarization.json"
python3 - "$dist/notarization.json" <<'PY'
import json, sys
result = json.load(open(sys.argv[1]))
if result.get('status') != 'Accepted':
    raise SystemExit('Apple notarization was not accepted; no release package is ready.')
print('PASS: Apple notarization accepted')
PY
xcrun stapler staple "$app_path"
xcrun stapler validate "$app_path"
codesign --verify --deep --strict "$app_path"
spctl --assess --type execute --verbose=2 "$app_path"
ditto -c -k --keepParent "$app_path" "$dist/$archive"
(cd "$dist" && shasum -a 256 "$archive" > "$archive.sha256")
python3 - "$project_dir" "$archive" "$version" <<'PY'
import hashlib, json, pathlib, subprocess, sys
root, name, version = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
archive = root / 'dist' / name
manifest = {
    'version': version,
    'source_commit': subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip(),
    'asset': name, 'sha256': hashlib.sha256(archive.read_bytes()).hexdigest(),
    'bytes': archive.stat().st_size, 'architectures': ['arm64', 'x86_64'],
    'developer_id_signed': True, 'notarization': 'Accepted',
    'ticket_stapled': True, 'gatekeeper': 'accepted',
    'compatibility': {'macOS_major': 27, 'official_helper_build': 24898},
}
(root / 'dist' / 'release-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
PY
printf 'Release package ready: %s\n' "$dist/$archive"
