# MMF Gesture Fix

**保留 Mac Mouse Fix 的连续手势，修正横向手势松手时的错误退出速度。**

[English](README.en.md) · [下载最新版](https://github.com/timmyagentic/mmf-gesture-fix/releases/latest) · [安装与排查](docs/INSTALLATION.md) · [技术原理](docs/ARCHITECTURE.md)

这是独立的 macOS 菜单栏辅助应用，针对官方 **Mac Mouse Fix 3.1.0（Helper build 24898）** 在 **macOS 27** 上的特定横向 HID 手势问题。它与官方应用一起运行，保留原有按钮映射和连续的桌面切换过程。

![MMF Gesture Fix 0.1.0 的真实控制窗口](docs/images/control-window.png)

截图来自实际运行的 0.1.0；界面目前为中文，Helper PID 随运行变化。

## 先确认是否适合你

| 条件 | 当前支持 |
| --- | --- |
| macOS | **27**；其他大版本不启动修复层 |
| Mac Mouse Fix | 官方签名的 Helper，build **24898** |
| 处理对象 | 横向原生 HID 手势的结束/取消事件 |
| CPU | Apple silicon 和 Intel，单个 Universal 应用包 |
| 权限 | macOS 辅助功能权限 |

应用校验 Helper 来源签名、进程、版本和事件形状。未知版本、其他来源、纵向手势、不完整序列、已标记事件均保持原样。`active` 只表示事件层已运行；当前 Helper 是否受支持，还要看版本和 `--status` 的 `source_supported`。

它不替代官方应用、不修改官方配置，与旧的 `mac-mouse-fix-macos-27-fix` 项目相互独立。没有自动更新器、登录启动项或后台网络请求。

## 解决什么问题

特定横向手势的退出速度可能与最近一次移动相反，导致松手时的错误惯性、回弹或额外桌面切换。本应用观察连续进度，只在完整序列的终止事件确有方向冲突时修正速度。

- 保留进度、时间戳、位置与修饰键，不替换成键盘快捷键。
- 依据**最近一次移动方向**判断，支持途中反向。
- 对官方 Helper 重发的同一终止载荷保持一致处理，避免重复修正。
- “暂停修复”切换为仅诊断，方便对照体验。

原始使用者已确认本机实际操作得到改善。自动检查覆盖策略和桥接边界；这些结果不代表所有鼠标、显示器、系统小版本或未来 Helper 都已验证。纵向 Mission Control 卡顿及其他无关问题不属于本版修复范围。

## 下载与安装

1. 从 [Releases](https://github.com/timmyagentic/mmf-gesture-fix/releases/latest) 下载 `MMF-Gesture-Fix-<版本>.app.zip`。
2. 解压，将 **MMF Gesture Fix.app** 拖入 `/Applications`，避免长期从下载或源码目录运行。
3. 保持官方 Mac Mouse Fix 运行，再打开修复器。
4. 在“系统设置 → 隐私与安全性 → 辅助功能”允许 **MMF Gesture Fix**，返回应用点击“重新检查权限”。
5. 确认 `active`、Helper build `24898` 和“修复开启”。

正式发布包采用 Developer ID 签名、Apple 公证并附带公证票据。Release 提供 SHA-256 与 `release-manifest.json`，用于核对下载内容和源码提交。

```sh
# 将同版本 ZIP 与 .sha256 放在同一目录
shasum -a 256 -c MMF-Gesture-Fix-0.1.0.app.zip.sha256
```

升级时从菜单栏**退出**旧实例，再替换 `/Applications` 中的应用并打开。不会自动下载安装更新。完整步骤、权限恢复和卸载见 [安装与排查](docs/INSTALLATION.md)。

## 日常使用

| 控件 | 行为 |
| --- | --- |
| 暂停修复 / 启用修复 | 在修复与仅诊断间切换；从下一段新手势重新判断 |
| 导出诊断 | 将最近最多 256 条受支持事件的记录保存到本机 |
| 重新检查权限 | 授权后重新尝试启动事件层 |
| 打开辅助功能设置 | 打开系统权限页面 |
| 关闭窗口 | 继续在菜单栏运行 |
| 菜单栏 → 退出 | 停止修复并退出；官方 Mac Mouse Fix 继续运行 |

对照测试建议保持相同映射，覆盖左右方向、慢速/快速多滚、临时反向、连续反向，以及首尾桌面边界。避免同时运行多个修改同类 HID 事件的修复器。

## 隐私与诊断

没有分析服务、上传接口或网络依赖；不记录键盘输入、屏幕图像、窗口标题或剪贴板。

本机数据位于 `~/Library/Application Support/MMF Gesture Fix/`：

- `status.json`：进程、可执行文件路径、Helper 版本、模式和计数。**包含本机路径，公开前请检查。**
- `gesture-diagnostics.json`：最多 256 条事件的时间、来源 PID、phase、progress、修正前后速度和实际修正标记。手动导出或退出时保存。
- 开关保存在修复器自己的 UserDefaults 中，不写官方应用偏好设置。

```sh
"/Applications/MMF Gesture Fix.app/Contents/MacOS/MMFGestureFix" --status
"/Applications/MMF Gesture Fix.app/Contents/MacOS/MMFGestureFix" --self-test
```

`--status` 只读现有运行状态；`--self-test` 只在内存构造事件，不投递输入。`--export-diagnostics` 请求已运行的实例导出，不启动第二个修复层。

## 从源码构建

需要 macOS、Xcode Command Line Tools（Swift、Clang、macOS SDK）；Python 3 仅用于发布元数据。应用本身没有第三方依赖，不需要 npm、Homebrew 包或 SwiftPM 下载。

```sh
git clone https://github.com/timmyagentic/mmf-gesture-fix.git
cd mmf-gesture-fix
scripts/test.sh
scripts/build.sh
scripts/verify.sh
```

输出 `build/MMF Gesture Fix.app`，默认使用 ad-hoc 签名用于开发。策略测试可在较旧 macOS 运行；HID 运行时自检只在 macOS 27 执行，其他系统会明确跳过，不能据此声称运行兼容。[发布说明](docs/RELEASING.md)介绍签名、公证、打包和远程校验。

## 项目结构与贡献

```text
Sources/App.swift            窗口、菜单栏与命令行入口
Sources/RepairEngine.swift   权限、Helper 识别、事件层和诊断
Sources/GesturePolicy.swift  无系统副作用的纯策略
Sources/HIDBridge.{h,m}      有限的 HID / Security 桥接
Sources/SelfTest.swift       策略自检
Tests/main.swift            独立测试入口
scripts/                    测试、Universal 构建、验证与公证
```

反馈请提供系统版本、Helper build、现象和暂停/启用对比；诊断文件先检查再分享。参阅 [贡献指南](CONTRIBUTING.md)、[安全说明](SECURITY.md)、[技术原理](docs/ARCHITECTURE.md)和[版本记录](CHANGELOG.md)。

## 许可与关联

[MIT License](LICENSE)。独立社区项目，与 [Mac Mouse Fix](https://github.com/noah-nuebling/mac-mouse-fix) 及其作者没有官方关联，不分发官方应用或源码。依赖 macOS 私有 API，系统更新可能改变其可用性。
