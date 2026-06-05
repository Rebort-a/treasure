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
├── 03~13.*          # Game modules
```

Each game module follows a three-layer architecture:
- `base.dart` — Data models, constants
- `foundation_manager.dart` — Shared game logic
- `local_manager.dart` / `net_manager.dart` — Local / LAN mode logic
- `local_page.dart` / `net_page.dart` — Local / LAN mode UI

### Code Style

- Use `flutter analyze` before committing (must pass with no issues)
- Follow Dart's [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use `ValueNotifier` + `ValueListenableBuilder` for state management (no Provider/Riverpod)

### Running Tests

```bash
flutter test
```

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

1. Ensure `flutter analyze` passes with no issues
2. Ensure `flutter test` passes
3. Commit with a clear message following [Conventional Commits](https://www.conventionalcommits.org/):
   - `feat:` for new features
   - `fix:` for bug fixes
   - `docs:` for documentation
   - `refactor:` for code refactoring
   - `test:` for adding tests
4. Push to your fork and open a Pull Request

## Reporting Issues

- Use GitHub Issues
- Include steps to reproduce, expected behavior, and actual behavior
- Mention your Flutter version and platform

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
