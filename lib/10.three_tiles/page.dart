import 'package:flutter/material.dart';

import '../00.common/widget/component/game_audio_scope.dart';

import '../00.common/widget/canvas/grid_boundary.dart';
import '../00.common/widget/navigator/notifier_navigator.dart';
import '../00.common/l10n/strings.dart';
import 'base.dart';
import 'manager.dart';
import '../00.common/model/notifiers.dart';

class ThreeTilesPage extends StatefulWidget {
  const ThreeTilesPage({super.key});

  @override
  State<ThreeTilesPage> createState() => _ThreeTilesPageState();
}

class _ThreeTilesPageState extends State<ThreeTilesPage> {
  late final Manager _manager;
  final _navigation = AlwaysNotifier<void Function(BuildContext)>((_) {});

  void _onResult() {
    final victory = _manager.result.value;
    if (victory == null) return;
    _navigation.value = (context) => showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(S.gameOver),
        content: Text(
          victory
              ? S.difficultyTimeSeconds(
                  _manager.difficulty.label,
                  _manager.elapsed.value,
                )
              : S.youLost,
        ),
        actions: [
          TextButton(
            child: Text(S.ok),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showDifficultyDialog() {
    _navigation.value = (context) => showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(S.chooseDifficulty),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: Difficulty.values
              .map(
                (difficulty) => RadioMenuButton<Difficulty>(
                  value: difficulty,
                  groupValue: _manager.difficulty,
                  onChanged: (value) {
                    if (value == null) return;
                    Navigator.pop(context);
                    _manager.changeDifficulty(value);
                  },
                  child: Text(difficulty.label),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _leavePage() {
    _manager.leavePage();
    _navigation.value = (context) => Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
    _manager = Manager();
    _manager.result.addListener(_onResult);
  }

  @override
  void dispose() {
    _manager.result.removeListener(_onResult);
    _navigation.dispose();
    _manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GameAudioScope(
    source: _manager,
    project: '10.three_tiles',
    child: PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leavePage();
      },
      child: Scaffold(appBar: _appBar(), body: _body()),
    ),
  );

  AppBar _appBar() => AppBar(
    title: Text(S.threeTiles),
    centerTitle: true,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: _leavePage,
    ),
    actions: [
      IconButton(
        icon: const Icon(Icons.refresh),
        onPressed: _manager.restartGame,
      ),
      IconButton(
        icon: const Icon(Icons.settings),
        onPressed: _showDifficultyDialog,
      ),
    ],
  );

  Widget _body() => Column(
    children: [
      NotifierNavigator(navigatorHandler: _navigation),
      _displayArea(),
      Expanded(child: _boardArea()),
      _propsArea(),
      _selectedArea(),
    ],
  );

  Widget _displayArea() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ValueListenableBuilder<int>(
          valueListenable: _manager.elapsed,
          builder: (_, value, __) =>
              Text(S.timeSeconds(value), style: const TextStyle(fontSize: 16)),
        ),
        ValueListenableBuilder<List<CardNotifier>>(
          valueListenable: _manager.cards,
          builder: (_, cards, __) => Text(
            S.remaining(cards.length),
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    ),
  );

  Widget _boardArea() => LayoutBuilder(
    builder: (_, constraints) {
      double boardRealWidth = constraints.maxWidth - 32;
      double ratio = boardRealWidth / Manager.boardVirtualWidth;
      double boardRealHeight = Manager.boardVirtualHeight * ratio;

      return SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          height: boardRealHeight, // 固定高度
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRect(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 绘制网格线
                CustomPaint(
                  size: Size(boardRealWidth, boardRealHeight),
                  painter: GridBoundary(
                    columnCount: 6,
                    rowCount: 8,
                    lineColor: Colors.grey[300]!,
                    lineWidth: 2.0,
                  ),
                ),

                // 卡片区域
                ValueListenableBuilder<List<CardNotifier>>(
                  valueListenable: _manager.cards,
                  builder: (_, cards, __) => Stack(
                    clipBehavior: Clip.none,
                    children: cards.map((c) => _buildCard(c, ratio)).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _buildCard(CardNotifier cardNotifier, double radio) {
    final cardRealSize = Manager.cardVirtualSize * radio;

    return ValueListenableBuilder<GameCard>(
      valueListenable: cardNotifier,
      builder: (_, card, __) {
        return Positioned(
          left: card.position.x * radio,
          top: card.position.y * radio,

          child: GestureDetector(
            onTap: () => _manager.selectCard(cardNotifier),
            child: Container(
              width: cardRealSize,
              height: cardRealSize,
              decoration: BoxDecoration(
                color: Color(card.type.info.color)
                    .withValues(alpha: card.enable ? 1 : 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: card.hint ? Colors.yellow : Colors.grey,
                  width: card.hint ? 3 : 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 2,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  card.type.info.emoji,
                  style: TextStyle(fontSize: cardRealSize * 0.5),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _propsArea() => Container(
    height: 60,
    margin: const EdgeInsets.symmetric(horizontal: 16),
    child: ValueListenableBuilder<List<PropType>>(
      valueListenable: _manager.props,
      builder: (_, props, __) => ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: props.length,
        itemBuilder: (_, i) {
          final p = props[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: GestureDetector(
              onTap: () => _manager.useProp(p),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 2,
                      offset: Offset(1, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(p.emoji, style: const TextStyle(fontSize: 24)),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _selectedArea() => Container(
    height: 70,
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey),
    ),
    child: ValueListenableBuilder<List<CardNotifier>>(
      valueListenable: _manager.selectedCards,
      builder: (_, cards, __) => ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        itemBuilder: (_, i) {
          final c = cards[i];
          return Container(
            width: 50,
            height: 50,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Color(c.type.info.color),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue, width: 2),
            ),
            child: Center(
              child: Text(
                c.type.info.emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          );
        },
      ),
    ),
  );
}

extension on Difficulty {
  String get label => switch (this) {
    Difficulty.easy => S.easy,
    Difficulty.medium => S.medium,
    Difficulty.hard => S.hard,
  };
}
