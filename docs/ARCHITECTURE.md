# Architecture and verification

## Event path

```text
Official signed Helper → native HID gesture → session event tap
    → verify process/build/OS/shape → pure direction policy
    → copy conflicting terminal payload and mark it → continue event stream
```

`App.swift` owns the menu bar, window and CLI. `RepairEngine.swift` owns the Accessibility-gated event tap, Helper lifecycle notifications, enable preference and bounded diagnostics. `GesturePolicy.swift` is pure stateful policy; `HIDBridge.m` is limited to SkyLight HID payload access, process identity and Security verification.

The event mask is CGEvent type 30. Accepted events must originate from a Helper verified against its official signing requirement, build 24898, on OS major 27, with motion 1 / flavor 3 and no repair marker. Other events are passed through.

## Direction policy

A begin event starts a sequence. Changed events update progress and the latest nonzero movement. Only end / cancel phases (4 / 8) can request a correction. Velocity must oppose the latest movement; non-finite values, missing begin state or incomplete sequences do not qualify.

The Helper can repost the same terminal payload after 200 / 500 ms. An exact phase/progress/velocity match within 600 ms reuses the previous decision, with preserved or restamped event timestamps. Corrected events carry a marker so they are not repaired again.

The bridge copies the CGEvent and reconstructs the recognized HID payload, reverses terminal X/Y velocity and preserves Z velocity, progress, HID options, event timestamp, location and flags. It does not mutate the original event or synthesize keyboard shortcuts.

## Lifecycle and privacy

The Helper is refreshed using application launch / termination notifications, not a polling timer. Permission retry is user-triggered. A bounded 256-record in-memory ring stores supported gesture diagnostics; export and shutdown write it locally. Status includes the executable path and must be reviewed before public sharing.

The app makes no network requests and installs no login item. Closing the window leaves the menu bar app alive; quitting stops the event tap. A second launch asks the existing instance to show its window and exits.

## Verification scope

- `scripts/test.sh`: 37 pure policy / eligibility checks. No Accessibility permission, HID posting or system configuration changes.
- `scripts/build.sh`: Swift / Objective-C compilation for arm64 and x86_64, Universal assembly, signing and an in-memory policy/HID self-test on macOS 27.
- `scripts/verify.sh`: bundle plist, strict signature, both architectures, bridge static analysis and in-memory self-test on macOS 27.
- CI on other macOS majors: compilation / policy / signature / static checks; the private-HID runtime self-test is explicitly skipped, not reported as passing.
- Public package: Developer ID + secure timestamp, Apple notarization, stapled ticket and Gatekeeper assessment; SHA-256 and source commit in the release manifest.

The original user accepted real gesture behavior on their setup. This public release does not claim a new hardware matrix or universal behavioral validation. CI cannot substitute for physical A/B testing.

## Boundaries

Private APIs may change in an OS update. Supporting a different Helper build requires fresh source/signature review, recorded event-shape evidence, focused regression tests and real gesture validation. Do not merely widen the version check. Official Mac Mouse Fix source is not bundled or modified by this companion.
