SHELL := /bin/sh

.DEFAULT_GOAL := help

.PHONY: help install dev check build bundle clean release

help: ## 显示可用命令
	@awk 'BEGIN {FS = ":.*## "; printf "Textboard\n\n"} /^[a-zA-Z_-]+:.*## / {printf "  %-12s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install: ## 安装前端依赖
	npm ci

dev: ## 启动 Tauri 开发模式
	npm run tauri:dev

check: ## 执行前端、Rust 格式及编译检查
	npm run build
	cargo fmt --manifest-path src-tauri/Cargo.toml --all -- --check
	cargo check --manifest-path src-tauri/Cargo.toml

build: ## 生成 Apple Silicon release 二进制
	npm run tauri:build -- --target aarch64-apple-darwin --no-bundle

bundle: check ## 使用本机 Developer ID 签名并公证 Apple Silicon 安装包
	./scripts/release-macos-arm64.sh

clean: ## 清理构建产物
	cargo clean --manifest-path src-tauri/Cargo.toml
	rm -rf dist

release: check ## 本地签名并公证；GitHub Release 需手动上传
	@test -n "$(VERSION)" || (echo "请提供 VERSION，例如 make release VERSION=0.1.0" && exit 1)
	@test "$$(node -p "require('./package.json').version")" = "$(VERSION)" || (echo "VERSION 必须与 package.json 一致" && exit 1)
	./scripts/release-macos-arm64.sh
