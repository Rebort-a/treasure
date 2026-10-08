# Contributing to Treasure

Thank you for your interest in contributing! 🎉

## Getting Started

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/your-username/treasure.git
   cd treasure
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development

### Project Structure

```
lib/
├── 00.common/       # Shared modules (engine, network, widgets)
├── 01.home/         # Home page
├── 02.lan_chat/     # LAN chat room
├── 03~18.*          # 游戏模块
```

Games separate data, logic and UI using either flat files or `base / middle / upper` directories:
- `base.dart` — Data models, constants
- `foundation_manager.dart` — Shared game logic
- `local_manager.dart` / `net_manager.dart` — Local / LAN mode logic
- `local_page.dart` / `net_page.dart` — Local / LAN mode UI

See [architecture](docs/architecture.md) for dependency rules, resource ownership, storage injection and the remaining legacy presentation coupling. Do not introduce cross-game imports or move UI into a data kernel.

### Code Style

- Use `flutter analyze lib` before committing (must pass with no issues)
- Format with `dart format lib test scripts`; CI verifies formatting without rewriting files
- Follow Dart's [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use `ValueNotifier` + `ValueListenableBuilder` for state management (no Provider/Riverpod)
- 新增或修改的说明性代码注释使用中文；保留工具指令和标识符原文。
- Prefer descriptive new types such as `TankGameManager`; avoid repository-wide renames without a migration plan.
- Keep convenience plugins inside their existing adapter files; do not import them in game kernels.

### Running Tests

```bash
dart format --output=none --set-exit-if-changed lib test scripts
flutter analyze lib
flutter test --coverage
dart run scripts/coverage_report.dart --check
```

The coverage report excludes generated localization code, reports missing LCOV files separately, and checks explicitly listed critical modules. See [quality and acceptance](docs/quality.md) for benchmark commands and manual platform checks.

### Building

```bash
# Web
flutter build web --release

# Android APK
flutter build apk --release

# Windows
flutter build windows --release
```

## Submitting Changes

1. Ensure formatting and `flutter analyze lib` pass with no issues
2. Ensure tests and coverage checks pass
3. Commit with a clear message following [Conventional Commits](https://www.conventionalcommits.org/):
   - `feat:` for new features
   - `fix:` for bug fixes
   - `docs:` for documentation
   - `refactor:` for code refactoring
   - `test:` for adding tests
4. Push to your fork and open a Pull Request

When working with an agent in this repository, obtain the user's permission before creating a commit. Never push automatically.

## Reporting Issues

- Use GitHub Issues
- Include steps to reproduce, expected behavior, and actual behavior
- Mention your Flutter version and platform

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
