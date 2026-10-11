# Changelog

## 0.1.0 — 2026-10-11

First public release of the independent MMF Gesture Fix companion.

- Native Swift menu bar app with repair / diagnostic-only modes and explicit permission retry.
- Narrow correction of conflicting terminal velocity for official Helper build 24898 on macOS 27.
- Continuous gesture progress, reversal handling and repeated terminal decisions preserved.
- Bounded local diagnostics and read-only status / non-posting self-test commands.
- Universal Developer ID signed, Apple-notarized, stapled application package.
- Chinese / English README, installation and removal guide, architecture, contribution and release documentation.

The earlier local 0.1.0 build was accepted by its original user. This release retains that application behavior and adds public packaging, secure signing timestamps and documentation; it does not expand the supported Helper / OS matrix. CI runtime skips on older macOS are explicit.
