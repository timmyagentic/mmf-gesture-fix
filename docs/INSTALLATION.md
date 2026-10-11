# 安装与排查 / Installation and troubleshooting

## 安装 / Install

从本项目 [GitHub Releases](https://github.com/timmyagentic/mmf-gesture-fix/releases/latest) 下载 ZIP，解压后拖到 `/Applications`。运行官方 Mac Mouse Fix，再打开修复器。发布包为 Universal，支持 Apple silicon 与 Intel；实际修复仍限 macOS 27 + 官方 Helper build 24898。

Download the ZIP, extract it, move the app to `/Applications`, and open it alongside official Mac Mouse Fix. Universal architecture support does not expand the OS / Helper compatibility boundary.

首次运行需要在系统设置的“隐私与安全性 → 辅助功能”中允许本应用。点击“重新检查权限”后确认 `active`、正确 Helper build 和修复开启。仅给官方 Mac Mouse Fix 授权不能替代给此独立应用授权。

Grant this companion Accessibility permission, then click **重新检查权限**. The official app's permission does not grant access to this separately identified companion.

## 更新 / Update

从菜单栏退出旧实例，再用新版替换 `/Applications/MMF Gesture Fix.app`。重新打开并检查权限；应用内没有自动更新功能。不要在旧构建目录和 Applications 中同时尝试运行两个副本：应用会优先唤起已有实例并退出新实例。

Quit the old instance before replacing the installed app. A second launch shows the existing instance rather than running two repair layers, so opening a new copy does not prove that the running executable changed.

## 常见状态 / Common states

| 状态 | 含义与处理 / Meaning and action |
| --- | --- |
| `waiting_accessibility` | 允许辅助功能权限，然后重试 / Grant permission, then retry |
| `unsupported_system` | 系统大版本不是 27，或私有 API 不可用 / OS major is not 27, or private APIs are unavailable |
| `event_tap_unavailable` | 事件层启动失败；核对权限后退出重开 / Check permissions and reopen |
| `active` + 未识别 Helper | 事件层运行但来源不符合要求；检查官方应用/版本 / Tap runs, but no verified eligible Helper is identified |
| `active` + build 24898 | 来源版本匹配；再确认修复开关 / Eligible build; also verify repair is enabled |
| 仅诊断 / diagnostics only | 已暂停修复；使用“启用修复” / Repair paused; click enable |

版本改变后不会猜测兼容性。请勿替换版本检查或关闭签名验证来强行适配新 Helper。

Unknown Helper builds pass through. Do not remove signature / version checks to force compatibility.

## Gatekeeper

正式下载包已签名、公证并 stapled。若 macOS 报告文件损坏、开发者验证失败或无法验证公证，请先重新下载，核对 SHA-256 并报告具体系统信息；不要通过删除 quarantine 或关闭 Gatekeeper 来绕过校验。

The public package is signed, notarized and stapled. If macOS rejects it, redownload, check the checksum and report the exact error rather than disabling Gatekeeper.

```sh
shasum -a 256 -c MMF-Gesture-Fix-0.1.0.app.zip.sha256
codesign --verify --deep --strict "/Applications/MMF Gesture Fix.app"
spctl --assess --type execute --verbose=2 "/Applications/MMF Gesture Fix.app"
```

## 对照体验 / Compare behavior

使用相同按钮映射、桌面布局和显示设置，在暂停与启用之间比较左右方向、速度变化、途中反向与桌面边界。普通滚动、其他手势和官方映射应保持。无法改善时可保持暂停或退出；不要通过放宽源版本检查排查。

Compare both modes under the same conditions. Ordinary scrolling and other gestures should remain unchanged. Pause or quit if it does not help.

## 卸载 / Remove

1. 从修复器菜单栏选择“退出”。关闭窗口不等于退出。
2. 将 `/Applications/MMF Gesture Fix.app` 移入废纸篓。
3. 可在辅助功能设置移除此应用的授权。
4. 如需清除诊断记录，将 `~/Library/Application Support/MMF Gesture Fix/` 移入废纸篓；这不涉及官方 Mac Mouse Fix 的配置。
5. 可选清除修复开关：`defaults delete local.timmy.mmf-gesture-fix RepairEnabled`。

Quit from the companion's menu bar menu, then move the app to Trash. Optionally remove its Accessibility entry, local support folder and its own repair preference. Official Mac Mouse Fix stays installed and unchanged. No login item or background service needs removal.
