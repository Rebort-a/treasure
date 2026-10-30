import 'dart:math';

import 'package:flutter/material.dart';

import '../00.common/widget/component/game_audio_scope.dart';

import '../00.common/widget/component/game_replay_board.dart';

import '../00.common/widget/navigator/notifier_navigator.dart';
import '../00.common/l10n/strings.dart';
import 'base.dart';
import 'manager.dart';
import '../00.common/widget/dialog/template_dialog.dart';
import '../00.common/model/notifiers.dart';

class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key});

  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  late final MemoryManager _manager;
  final _navigation = AlwaysNotifier<void Function(BuildContext)>((_) {});

  void _showSelector() {
    _navigation.value = (context) => DialogTemplate.intSliderDialog(
      context: context,
      title: S.setDifficulty,
      sliderData: IntSliderData(
        start: _manager.minDifficulty,
        end: _manager.maxDifficulty,
        value: _manager.difficulty,
        step: 1,
      ),
      onConfirm: _manager.changeDifficulty,
    );
  }

  void _leavePage() {
    _manager.leavePage();
    _navigation.value = (context) => Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
    _manager = MemoryManager();
  }

  @override
  void dispose() {
    _navigation.dispose();
    _manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GameAudioScope(
    source: _manager,
    project: '15.memory_card',
    child: PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _leavePage();
      },
      child: Scaffold(appBar: _buildAppBar(), body: _buildBody()),
    ),
  );

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(S.memoryCard),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: _leavePage,
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _manager.resetGame,
        ),
        IconButton(icon: const Icon(Icons.tune), onPressed: _showSelector),
      ],
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        NotifierNavigator(navigatorHandler: _navigation),
        _buildDisplayArea(),
        Expanded(child: _buildBoardArea()),
      ],
    );
  }

  /// 1. 文本显示区：进行中显示剩余对数，结束后显示完成用时
  Widget _buildDisplayArea() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ValueListenableBuilder<String>(
        valueListenable: _manager.displayInfo,
        builder: (_, value, __) => Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// 棋盘区：Wrap 布局，卡牌固定尺寸，配对成功后该格留空不重排
  /// 游戏结束后使用与其他单机、联机棋盘相同的蒙版和重开按钮。
  Widget _buildBoardArea() {
    return ValueListenableBuilder<bool>(
      valueListenable: _manager.gameOver,
      builder: (_, over, __) =>
          ValueListenableBuilder<List<MemoryCardNotifier>>(
            valueListenable: _manager.cards,
            builder: (_, cards, __) => GameReplayBoard(
              finished: over,
              onReplay: _manager.resetGame,
              child: Center(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: List.generate(
                      cards.length,
                      (i) => SizedBox(
                        width: 72,
                        height: 72,
                        child: CardView(
                          card: cards[i],
                          onTap: () => _manager.flipCard(i),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
    );
  }
}

/// 独立卡牌视图：3D 翻面动画（TweenAnimationBuilder + Transform.rotationY）
class CardView extends StatelessWidget {
  final MemoryCardNotifier card;
  final VoidCallback onTap;

  const CardView({super.key, required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MemoryCard>(
      valueListenable: card,
      builder: (_, memoryCard, __) {
        final state = memoryCard.state;
        // 匹配成功：占位留空（保留 Wrap 格位，不重排，符合记忆翻牌规则）
        if (state == CardState.matched) return const SizedBox.shrink();
        final target = state == CardState.hidden ? 0.0 : 1.0;
        return GestureDetector(
          onTap: onTap,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: target),
            duration: const Duration(milliseconds: 300),
            builder: (_, v, __) {
              // v: 0→1 翻开，1→0 翻回；<0.5 显示背面，>=0.5 显示正面
              final showFront = v >= 0.5;
              final face = showFront
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(pi), // 抵消镜像
                      child: _frontFace(),
                    )
                  : _backFace();
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationY(pi * v),
                child: face,
              );
            },
          ),
        );
      },
    );
  }

  Widget _frontFace() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(1, 1)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(card.pattern, style: const TextStyle(fontSize: 30)),
    );
  }

  Widget _backFace() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.deepPurple, Colors.indigo],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.indigo.shade700),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(1, 1)),
        ],
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.auto_awesome, color: Colors.white70, size: 28),
    );
  }
}
