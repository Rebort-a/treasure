# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.1] - 2026-09-01
release: Simplify version display in About section

## [1.2.0] - 2026-09-01
Release: 跨平台游戏合集 1.2 中版本更新：本地化、About 真实版本号、移除庆祝弹窗、CI 修复

### Added
- show real app version from package info in About

### Changed
- declare github-pages environment for Pages deploy
- bump GitHub Actions artifacts and deploy-pages to latest
- replace celebration dialogs with simple completion-time info

### Other
- docs: add missing v1.1.0 changelog entry

## [1.1.0] - 2026-09-01

升级工具链、插件，并支持网页端聊天内的文件/图片分享，修复 Java 21 下的 Android 构建失败。

### Changed
- Flutter 3.44.0 → 3.47.2 (Dart 3.13.2)
- Android Gradle Plugin 8.9.1 → 9.1.0 ; Gradle 8.14.1 → 9.3.1 ; Kotlin 1.9.20 → 2.4.0
- file_picker 11.0.2 → 12.1.2（迁移到 v12 API）；image_picker 1.2.2 → 1.2.3
- Dart SDK 约束 ^3.12.0 → ^3.13.0
- 网页端聊天支持发送文件/图片（跨平台 XFile/PlatformFile.readAsBytes，移除 dart:io 限制）
- CI：web 产物重命名 web-build → web；迁移 GitHub Pages 部署到 flutter.yml；升级 actions
- 发布脚本支持 Conventional Commits 前缀驱动、自动分类 CHANGELOG、等待并校验 CI

### Fixed
- Android 构建在 Java 21 下失败，回退编译目标到 Java 17

## [1.0.0] - 2026-08-31

首个正式版本：跨平台游戏合集，14 单机 + 5 联机 + 1 聊天室，纯 Dart 零依赖内核。

### Added
- **14 Local Games**: Animal Chess, Elemental Battle, Gobang, Greedy Snake, Go, Sudoku, Guess, Three Tiles, Spaceship, Soft Body, Minecraft, Tower Defense, Memory Match, Schulte
- **5 LAN Multiplayer Games**: Animal Chess, Elemental Battle, Gobang, Greedy Snake, Go
- **LAN Chat Room**: Text/image/file chat with emoji panel, BlurHash progressive loading, XOR-encrypted transport
- **Pure Dart 3D Engine**: Minecraft-style voxel renderer via CustomPainter (no OpenGL/Vulkan)
- **Procedural World Generation**: 7 biomes via temperature/humidity noise
- **Soft Body Physics**: Spring-mass model with Euler/Verlet integration
- **Zero-Config LAN Play**: UDP broadcast/multicast room discovery, ACK + retry, exponential-backoff reconnection
- **Tower Defense**: Co-op defense, random maps, 7 tower types, 4 enemy types, 20 waves
- **Memory Match & Schulte Grid**: Memory pairing & attention training (regular/irregular modes, full-bleed board)
- **Dual Network Mode**: TCP+UDP (native) or WebSocket (web), switchable via one line
- **Cross-Platform**: Android, iOS, Web, Windows, Linux, macOS
- **i18n**: Chinese and English localization
- **Persistent Storage**: Game progress, high scores, settings saved locally
- **CI/CD**: GitHub Actions for analyze, test, build, GitHub Pages deployment & multi-platform release
