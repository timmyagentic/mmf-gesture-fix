# MMF Gesture Fix

Use Swift for the app lifecycle, UI and gesture policy. Objective-C is limited to HID and Security bridges. This is a separate companion project; do not modify Mac Mouse Fix or the original MMF27 repository.

Only verified official Helper build 24898 on macOS 27 is eligible. Unknown sources/versions, other gestures and incomplete gestures pass unchanged. Preserve progress and timestamps. Never replace gestures with keyboard shortcuts.

Run scripts/test.sh, scripts/build.sh and scripts/verify.sh. Non-posting self-tests must not pollute runtime diagnostic counters. Keep physical mouse A/B results distinct from automated verification. Do not install auto-start or publish without explicit authorization.
