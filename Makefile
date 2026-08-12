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

build: ## 生成当前平台 release 二进制
	npm run tauri:build -- --no-bundle

bundle: ## 生成当前平台安装包
	npm run tauri:build

clean: ## 清理构建产物
	cargo clean --manifest-path src-tauri/Cargo.toml
	rm -rf dist

release: check ## 创建并推送版本标签，例如 make release VERSION=0.1.0
	@test -n "$(VERSION)" || (echo "请提供 VERSION，例如 make release VERSION=0.1.0" && exit 1)
	@test "$$(node -p "require('./package.json').version")" = "$(VERSION)" || (echo "VERSION 必须与 package.json 一致" && exit 1)
	git tag -a "v$(VERSION)" -m "Release v$(VERSION)"
	git push origin "v$(VERSION)"
