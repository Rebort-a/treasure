# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
