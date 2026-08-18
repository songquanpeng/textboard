# Textboard

Textboard 是一个使用 SwiftUI 与 AppKit 构建的原生 macOS 文字暂存工具。它按时间归类文稿、自动保存，并在重启后恢复现场。

## 功能

- SwiftUI 原生分栏、侧边栏列表、菜单、设置和深浅色外观
- 基于 `NSTextView` 的纯文本编辑器，支持系统撤销与直接输入 `Tab`
- 文稿按置顶、今天、昨天、过去 7 天和更早归类
- 全文搜索、文稿置顶、字数统计和窗口始终置顶
- 侧边栏原生滑动操作与右键菜单
- `⌘N` 新建文稿，`⌘F` 搜索（同时保留 `⌘K`）
- 无账号、无云端依赖、无第三方运行时

最低支持 macOS 14。原 Tauri 版本的数据会自动沿用：bundle identifier 和 `workspace.json` 的位置与格式保持不变。

## 开发与测试

项目使用 Swift Package Manager，不需要安装第三方依赖。

```bash
make install
make test
make dev
```

完整检查与本机 App 打包：

```bash
make check
make bundle
```

文稿保存在 `~/Library/Application Support/com.justsong.textboard/workspace.json`，写入使用系统原子替换。

## 发布

推送 `v*` 标签后，GitHub Actions 会测试并构建同时支持 Apple Silicon 与 Intel 的通用 macOS App，然后创建 GitHub Release。

```bash
make release VERSION=0.3.0
```

发布包使用 ad-hoc 签名，未经过 Apple Developer ID 公证；首次打开时 macOS 可能要求在“隐私与安全性”中确认。
