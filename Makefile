SHELL := /bin/sh

.DEFAULT_GOAL := help

.PHONY: help install dev test check build bundle archive clean release

help: ## 显示可用命令
	@awk 'BEGIN {FS = ":.*## "; printf "Textboard (native macOS)\n\n"} /^[a-zA-Z_-]+:.*## / {printf "  %-12s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install: ## 检查 Swift 工具链（无第三方依赖）
	@swift --version

dev: ## 运行原生 macOS 应用
	swift run Textboard

test: ## 运行模型、迁移和持久化检查
	./scripts/test.sh

check: test ## 编译 debug 与 release 配置
	swift format lint --recursive --strict Sources Tests Package.swift
	swift build
	swift build -c release

build: ## 生成 release 可执行文件
	swift build -c release

bundle: check ## 生成当前架构的 Textboard.app
	./scripts/build-app.sh

archive: check ## 生成 Apple Silicon + Intel 通用发布包
	./scripts/package-release.sh

clean: ## 清理构建产物
	swift package clean
	rm -rf build

release: check ## 创建并推送版本标签，例如 make release VERSION=0.2.0
	@test -n "$(VERSION)" || (echo "请提供 VERSION，例如 make release VERSION=0.2.0" && exit 1)
	@test "$$(tr -d '[:space:]' < VERSION)" = "$(VERSION)" || (echo "VERSION 必须与 VERSION 文件一致" && exit 1)
	git tag -a "v$(VERSION)" -m "Release v$(VERSION)"
	git push origin "v$(VERSION)"
