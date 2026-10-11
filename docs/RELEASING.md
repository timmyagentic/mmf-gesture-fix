# Releasing

Public releases use a local macOS 27 machine with Xcode Command Line Tools, a Developer ID Application certificate and an existing `notarytool` Keychain profile. Credentials and signing keys must never enter Git or release assets. Hosted CI does not receive Apple credentials.

## Prepare

1. Review the supported OS / official Helper build. Keep app code, plist versions, UI, diagnostics and changelog consistent.
2. Review the source tree for credentials, local account paths, exported diagnostics and unrelated data. Keep generated `build/` and `dist/` out of Git.
3. Commit the candidate and require a clean working tree. Run CI; skips on older OS versions are not physical gesture verification.

## Package

```sh
export MMF_GESTURE_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)'
export MMF_GESTURE_NOTARY_PROFILE='your-stored-keychain-profile'
scripts/release.sh
```

This runs policy tests, builds both architectures, verifies the bundle, submits the ZIP to Apple, requires `Accepted`, staples the app, checks Gatekeeper, repackages the stapled app and writes the checksum / public manifest.

Only publish these artifacts:

- `MMF-Gesture-Fix-<version>.app.zip`
- `MMF-Gesture-Fix-<version>.app.zip.sha256`
- `release-manifest.json`

`dist/notarization.json` is local submission evidence, not a required public asset. The manifest has the source commit, version, architectures, checksum and signing/notarization results without private machine paths or Keychain profile names.

## Publish and verify

Create the version tag on the validated source commit and create a GitHub Release with the three artifacts. Select stable / prerelease deliberately; do not claim release completion while it is still a draft or while assets are missing.

After publication, confirm public visibility and tag resolution. Download the ZIP and its checksum from GitHub into an independent temporary directory, verify SHA-256, unpack it, validate the stapled ticket, signature, version, both architectures and Gatekeeper. Opening the app is a separate installation / Accessibility acceptance step; publication does not replace an existing local instance.
