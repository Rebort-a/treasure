import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/service/storage_service.dart';
import 'package:treasure/18.match_three/base/match_board.dart';
import 'package:treasure/18.match_three/middle/match_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('通关分数超过历史记录时更新并保存', () async {
    final storage = StorageService.instance;
    storage.resetForTesting();
    final directory = await Directory.systemTemp.createTemp('match_three_');
    storage.overrideBaseDir = directory;
    MatchManager? manager;
    try {
      await storage.init();
      await storage.write('match_three', {
        'highScore': 1,
      }, project: '18.match_three');
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
        ..['score'] = 0
        ..['movesLeft'] = 1;
      data['moveNumber'] = data['initialMoves'] - 1;
      data['score'] = data['scoreTarget'];

      manager = MatchManager(seed: 7)..reduceMotion = true;
      manager.loadState(data);
      manager.swap(10, 2);

      for (var attempt = 0; attempt < 100 && manager.busy.value; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(manager.board!.status, MatchStatus.won);
      expect(manager.brokeRecord.value, isTrue);
      final saved = await storage.read(
        'match_three',
        project: '18.match_three',
      );
      expect(saved['highScore'], manager.board!.score);
    } finally {
      manager?.dispose();
      storage.resetForTesting();
      final tempRoot = Directory.systemTemp.absolute.path;
      if (!directory.absolute.path.startsWith(
            '$tempRoot${Platform.pathSeparator}',
          ) ||
          !directory.uri.pathSegments.any(
            (part) => part.startsWith('match_three_'),
          )) {
        throw StateError('Unexpected temporary directory: ${directory.path}');
      }
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  });

  test('失败局不会记录为破纪录', () async {
    final storage = StorageService.instance;
    storage.resetForTesting();
    final directory = await Directory.systemTemp.createTemp('match_three_');
    storage.overrideBaseDir = directory;
    MatchManager? manager;
    try {
      await storage.init();
      await storage.write('match_three', {
        'highScore': 1,
      }, project: '18.match_three');
      final data = MatchBoard.random(seed: 9).toJson()..['movesLeft'] = 1;
      data['moveNumber'] = data['initialMoves'] - 1;

      manager = MatchManager(seed: 9)..reduceMotion = true;
      manager.loadState(data);
      for (
        var attempt = 0;
        attempt < 100 && manager.highScore.value != 1;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      final move = manager.board!.legalMoves.first;
      manager.swap(move.$1, move.$2);

      expect(manager.board!.status, MatchStatus.lost);
      expect(manager.brokeRecord.value, isFalse);
      expect(manager.highScore.value, 1);
      expect(
        (await storage.read(
          'match_three',
          project: '18.match_three',
        ))['highScore'],
        1,
      );
    } finally {
      manager?.dispose();
      storage.resetForTesting();
      final tempRoot = Directory.systemTemp.absolute.path;
      if (!directory.absolute.path.startsWith(
            '$tempRoot${Platform.pathSeparator}',
          ) ||
          !directory.uri.pathSegments.any(
            (part) => part.startsWith('match_three_'),
          )) {
        throw StateError('Unexpected temporary directory: ${directory.path}');
      }
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  });
}
