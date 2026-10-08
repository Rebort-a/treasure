import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/service/json_store.dart';
import 'package:treasure/18.match_three/base/match_board.dart';
import 'package:treasure/18.match_three/middle/match_manager.dart';

/// 每个测试持有独立存储，不修改单例、不创建磁盘目录。
class _MemoryStore implements JsonStore {
  Map<String, dynamic> data;
  final Completer<Map<String, dynamic>>? pendingRead;
  int writes = 0;

  _MemoryStore({int? highScore, this.pendingRead})
    : data = {if (highScore != null) 'highScore': highScore};

  @override
  Future<Map<String, dynamic>> read(
    String name, {
    String project = '00.common',
  }) async {
    expectSync(name, 'match_three');
    expectSync(project, '18.match_three');
    return pendingRead == null ? Map.of(data) : pendingRead!.future;
  }

  @override
  Future<void> write(
    String name,
    Map<String, dynamic> data, {
    String project = '00.common',
  }) async {
    expectSync(name, 'match_three');
    expectSync(project, '18.match_three');
    this.data = Map.of(data);
    writes++;
  }
}

Map<String, dynamic> _winningState() {
  final data = MatchBoard.random(seed: 7).toJson()
    ..['pieces'] = [
      for (var index = 0; index < MatchBoard.cells; index++)
        [
          index + 1,
          {0: 0, 1: 0, 2: 1, 3: 0, 10: 0}[index] ??
              (index ~/ MatchBoard.side * 2 + index % MatchBoard.side) %
                  MatchBoard.kinds,
          PieceEffect.none.index,
        ],
    ]
    ..['nextId'] = MatchBoard.cells + 1
    ..['ice'] = List.filled(MatchBoard.cells, 0)
    ..['targets'] = {'0': 1, '1': 1}
    ..['collected'] = [0, 1, 0, 0, 0, 0]
    ..['movesLeft'] = 1;
  data['moveNumber'] = data['initialMoves'] - 1;
  data['score'] = data['scoreTarget'];
  return data;
}

Future<void> _finishFrames(WidgetTester tester, MatchManager manager) async {
  for (var frame = 0; frame < 10 && manager.busy.value; frame++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
  await tester.pump(const Duration(seconds: 1));
  expect(manager.busy.value, isFalse);
}

void main() {
  testWidgets('通关分数超过历史记录时更新并保存', (tester) async {
    final storage = _MemoryStore(highScore: 1);
    final manager = MatchManager(seed: 7, storage: storage)
      ..reduceMotion = true;
    addTearDown(manager.dispose);
    manager.loadState(_winningState());
    manager.swap(10, 2);
    await _finishFrames(tester, manager);

    expect(manager.board!.status, MatchStatus.won);
    expect(manager.brokeRecord.value, isTrue);
    expect(storage.data['highScore'], manager.board!.score);
    expect(storage.writes, 1);
  });

  testWidgets('失败局不会记录为破纪录', (tester) async {
    final storage = _MemoryStore(highScore: 1);
    final manager = MatchManager(seed: 9, storage: storage)
      ..reduceMotion = true;
    addTearDown(manager.dispose);
    await tester.pump();
    final data = MatchBoard.random(seed: 9).toJson()..['movesLeft'] = 1;
    data['moveNumber'] = data['initialMoves'] - 1;
    manager.loadState(data);
    final move = manager.board!.legalMoves.first;
    manager.swap(move.$1, move.$2);
    await _finishFrames(tester, manager);

    expect(manager.board!.status, MatchStatus.lost);
    expect(manager.brokeRecord.value, isFalse);
    expect(manager.highScore.value, 1);
    expect(storage.data['highScore'], 1);
    expect(storage.writes, 0);
  });

  testWidgets('异步加载旧记录完成后才判断破纪录，不覆盖更高的旧记录', (tester) async {
    final pending = Completer<Map<String, dynamic>>();
    final storage = _MemoryStore(highScore: 100000, pendingRead: pending);
    final manager = MatchManager(seed: 7, storage: storage)
      ..reduceMotion = true;
    addTearDown(manager.dispose);
    manager.loadState(_winningState());
    manager.swap(10, 2);
    expect(storage.writes, 0);
    pending.complete({'highScore': 100000});
    await _finishFrames(tester, manager);

    expect(manager.highScore.value, 100000);
    expect(manager.brokeRecord.value, isFalse);
    expect(storage.writes, 0);
  });

  testWidgets('释放后到达的存储结果不会通知已释放状态', (tester) async {
    final pending = Completer<Map<String, dynamic>>();
    final manager = MatchManager(
      generate: false,
      storage: _MemoryStore(pendingRead: pending),
    );
    manager.dispose();
    pending.complete({'highScore': 100});
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('注入存储的两个 Manager 不共享记录', (tester) async {
    final alice = MatchManager(storage: _MemoryStore(highScore: 100));
    final bob = MatchManager(storage: _MemoryStore(highScore: 200));
    addTearDown(alice.dispose);
    addTearDown(bob.dispose);
    await tester.pump();
    expect(alice.highScore.value, 100);
    expect(bob.highScore.value, 200);
  });

  testWidgets('非法旧记录不会进入展示状态', (tester) async {
    final manager = MatchManager(storage: _MemoryStore(highScore: -1));
    addTearDown(manager.dispose);
    await tester.pump();
    expect(manager.highScore.value, 0);
  });
}
