# Textboard

一个基于 Tauri 的轻量文字暂存工具：按时间归类文稿、自动保存、重启恢复。

## 功能

- 左侧文稿列表，按置顶、今天、昨天、过去 7 天和更早归类
- 输入后自动保存到本地，关闭窗口后再次打开会恢复现场
- 全文搜索、文稿置顶、深浅色模式和字数统计
- `⌘/Ctrl + N` 新建文稿，`⌘/Ctrl + K` 搜索
- 无账号、无云端依赖

## 开发

```bash
make install
make dev
```

## 构建桌面应用

```bash
make bundle
```

文稿保存在系统应用数据目录的 `workspace.json` 中；写入使用临时文件替换，避免异常退出时留下半份数据。

## 发布

推送 `v*` 标签后，GitHub Actions 会自动构建 macOS（Apple Silicon 和 Intel）、Windows x64 以及 Linux x64 安装包，并创建 GitHub Release。

```bash
make release VERSION=0.1.3
```
