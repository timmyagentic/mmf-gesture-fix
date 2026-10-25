# Contributing

Issues and pull requests are welcome. Start with the compatibility table in the README; this is a narrowly scoped companion, not a general gesture remapper.

## Reports

Include macOS version, official Helper build, mouse / mapping, expected vs actual behavior, and a paused-versus-enabled comparison. Do not attach passwords, account information, full system logs or unreviewed local paths. A minimal gesture diagnostic export is preferable to broad telemetry.

## Development

Read [AGENTS.md](AGENTS.md) and [architecture](docs/ARCHITECTURE.md). Use Swift for application lifecycle, UI and policy; limit Objective-C to HID / Security bridges. Preserve unrelated events, source verification, progress, timestamps and the correction marker. Do not replace continuous gestures with keyboard shortcuts.

For behavior changes, add a focused regression that fails before the fix. Run:

```sh
scripts/test.sh
scripts/build.sh
scripts/verify.sh
```

Record your OS and any skipped HID runtime check. New Helper / OS support needs real event and physical gesture evidence, not just a relaxed version check. Document changes in [CHANGELOG.md](CHANGELOG.md). Do not add background polling, telemetry, login startup or an updater without a separate product decision.

Pull requests should state the concrete trigger, resulting behavior and validation. Development signing is ad-hoc; do not submit signing identities, Keychain profiles or private keys. See [releasing](docs/RELEASING.md) for maintainers' package validation.

## Merge and branch cleanup

Follow [the repository workflow](AGENTS.md#repository-workflow-and-branch-protection): default-branch changes require a PR and squash merging, with resolved review conversations and no administrator bypass. Keep automatic remote-branch deletion enabled. Local branches and worktrees remain for the existing Tingjun Workspace archive workflow; do not use `--delete-branch` during merge. Existing CI requirements remain unchanged.
