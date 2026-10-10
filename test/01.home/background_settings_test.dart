import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/service/storage_service.dart';
import 'package:treasure/01.home/background_settings.dart';

final imageBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAAXNSR0IArs4c6QAAAA'
  'RnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAQSURBVBhXY/jPw'
  'PCfARkAAB7zAf+x9MCaAAAAAElFTkSuQmCC',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  final storage = StorageService.instance;
  final settings = BackgroundSettings.instance;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('treasure_background_');
    storage.resetForTesting();
    storage.overrideBaseDir = directory;
    settings.resetForTesting();
    await storage.init();
  });

  tearDown(() async {
    settings.resetForTesting();
    storage.resetForTesting();
    await directory.delete(recursive: true);
  });

  test('背景图片可重新加载和清除，且不影响通用设置', () async {
    await storage.write('settings', {'language': 1, 'themeMode': 2});
    await settings.setImage(imageBytes);
    expect(settings.image.value, imageBytes);
    settings.resetForTesting();
    await settings.load();
    expect(settings.image.value, imageBytes);
    expect(await storage.read('settings'), {'language': 1, 'themeMode': 2});
    await settings.setImage(null);
    settings.resetForTesting();
    await settings.load();
    expect(settings.image.value, isNull);
    expect(await storage.read('background', project: '01.home'), isEmpty);
  });

  test('无效或过大的图片不覆盖原有背景', () async {
    await settings.setImage(imageBytes);
    await expectLater(
      settings.setImage(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<Exception>()),
    );
    await expectLater(
      settings.setImage(Uint8List(BackgroundSettings.maxImageBytes + 1)),
      throwsFormatException,
    );
    expect(settings.image.value, imageBytes);
  });

  test('损坏的持久化数据回退到默认背景', () async {
    await storage.write('background', {
      'image': 'not base64',
    }, project: '01.home');
    await settings.load();
    expect(settings.image.value, isNull);
  });
}
