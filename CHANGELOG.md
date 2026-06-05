# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-06-06

### Fixed
- StorageService now uses `path_provider` for Android/iOS persistent storage path

## [1.0.0] - 2026-06-05

### Added
- **11 Local Games**: Animal Chess, Elemental Battle, Gobang, Greedy Snake, Go, Sudoku, Guess, Three Tiles, Spaceship, Soft Body, Minecraft
- **5 LAN Multiplayer Games**: Animal Chess, Gobang, Go, Greedy Snake, Elemental Battle
- **LAN Chat Room**: Pure text chat with image/file/emoji support
- **Pure Dart 3D Engine**: Minecraft-style voxel renderer with CustomPainter, no OpenGL/Vulkan
- **Procedural World Generation**: 7 biomes via temperature/humidity noise
- **Soft Body Physics**: Spring-mass model with Euler/Verlet integration
- **Zero-Config LAN Play**: UDP broadcast/multicast room discovery
- **Cross-Platform**: Android, iOS, Web, Windows, Linux
- **i18n**: Chinese and English localization
- **Persistent Storage**: Game progress, high scores, settings saved locally
- **CI/CD**: GitHub Actions for analyze, test, build, and GitHub Pages deployment
