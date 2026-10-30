import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/model/app_item_type.dart';
import 'package:treasure/00.common/service/storage_service.dart';
import 'package:treasure/01.home/middle/home_state.dart';

void main() {
  final storage = StorageService.instance;
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('treasure_home_state_');
    storage.resetForTesting();
    storage.overrideBaseDir = directory;
    await storage.init();
  });

  tearDown(() async {
    storage.resetForTesting();
    await directory.delete(recursive: true);
  });

  test('最近应用过滤无效记录，去重并按使用顺序持久化最多三项', () async {
    await storage.writeList('recent_apps', [
      AppItemType.gobang.name,
      'unknown',
      42,
      AppItemType.gobang.name,
      AppItemType.guess.name,
      AppItemType.sudoku.name,
      AppItemType.memoryCard.name,
    ], project: '01.home');
    final state = HomeState();
    addTearDown(state.dispose);
    await state.loadRecentApps();
    expect(state.recentApps.value, [
      AppItemType.gobang,
      AppItemType.guess,
      AppItemType.sudoku,
    ]);

    await state.rememberApp(AppItemType.guess);
    await state.rememberApp(AppItemType.memoryCard);
    final expected = [
      AppItemType.memoryCard,
      AppItemType.guess,
      AppItemType.gobang,
    ];
    expect(state.recentApps.value, expected);
    expect(
      await storage.readList('recent_apps', project: '01.home'),
      expected.map((item) => item.name).toList(),
    );
    final reloaded = HomeState();
    addTearDown(reloaded.dispose);
    await reloaded.loadRecentApps();
    expect(reloaded.recentApps.value, expected);
  });

  test('异步加载不能覆盖加载期间新产生的最近使用记录', () async {
    await storage.writeList('recent_apps', [
      AppItemType.gobang.name,
    ], project: '01.home');
    final state = HomeState();
    addTearDown(state.dispose);
    final loading = state.loadRecentApps();
    final saving = state.rememberApp(AppItemType.guess);
    await Future.wait([loading, saving]);
    expect(state.recentApps.value, [AppItemType.guess]);
    expect(await storage.readList('recent_apps', project: '01.home'), [
      AppItemType.guess.name,
    ]);
  });

  test('首页销毁后，待完成的记录加载不再更新已释放状态', () async {
    await storage.writeList('recent_apps', [
      AppItemType.gobang.name,
    ], project: '01.home');
    final state = HomeState();
    final loading = state.loadRecentApps();
    state.dispose();
    await expectLater(loading, completes);
  });
}
