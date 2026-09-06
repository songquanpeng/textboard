# Textboard

一个基于 Tauri 的轻量文字暂存工具：按时间归类文稿、自动保存、重启恢复。

## 功能

- 左侧文稿列表，按置顶、今天、昨天、过去 7 天和更早归类
- 输入后自动保存到本地，关闭窗口后再次打开会恢复现场
- 全文搜索、文稿置顶、深浅色模式和字数统计
- 文稿向右滑动可快速删除
- 编辑器使用等宽代码字体
- 编辑器内可直接输入 `Tab` 制表符
- 一键切换窗口始终置顶
- `⌘/Ctrl + N` 新建文稿，`⌘/Ctrl + K` 搜索
- 无账号、无云端依赖

## 开发

```bash
make install
make dev
```

## 构建桌面应用

只支持 Apple Silicon Mac（arm64）。普通 release 二进制：

```bash
make build
```

文稿保存在系统应用数据目录的 `workspace.json` 中；写入使用临时文件替换，避免异常退出时留下半份数据。

## 本地签名与发布

GitHub Actions 只运行代码检查，不打包、不持有 Apple 凭据。正式安装包必须在本机使用 `Developer ID Application` 证书签名，并通过 Apple 公证。

首次发布前，在钥匙串安装 `Developer ID Application` 证书，并把公证凭据存入本机钥匙串（密码会交互式输入，不要写进命令或仓库）：

```bash
xcrun notarytool store-credentials TextboardNotary \
  --apple-id "<你的 Apple ID>" \
  --team-id "<你的 Team ID>"
```

生成签名、公证并装订票据的 arm64 DMG：

```bash
make release VERSION=0.3.2
```

产物位于 `build/Textboard-0.3.2-macos-arm64.dmg`。确认后手动创建并上传 GitHub Release：

```bash
git tag -a v0.3.2 -m "Release v0.3.2"
git push origin main
git push origin v0.3.2
gh release create v0.3.2 build/Textboard-0.3.2-macos-arm64.dmg \
  --title "Textboard v0.3.2" \
  --generate-notes
```

证书私钥始终保留在本机钥匙串；`.p8`、`.p12`、`.cer` 和 `.env` 文件均被 Git 忽略。
