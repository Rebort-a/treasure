import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show EagerGestureRecognizer;

import '../../00.common/l10n/strings.dart';
import '../base/match_board.dart';
import '../middle/match_manager.dart';
import 'animal_piece.dart';

class MatchBoardWidget extends StatefulWidget {
  final MatchManager manager;
  final MatchView view;

  const MatchBoardWidget({
    super.key,
    required this.manager,
    required this.view,
  });

  @override
  State<MatchBoardWidget> createState() => _MatchBoardWidgetState();
}

class _MatchBoardWidgetState extends State<MatchBoardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );
  bool _animate = true;
  Offset? _dragStart;
  int? _pointer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate = !MediaQuery.disableAnimationsOf(context);
    if (_animate) {
      if (!_clock.isAnimating) _clock.repeat();
    } else {
      _clock.stop();
    }
  }

  int? _cellAt(Offset position, double cell) {
    final row = (position.dy / cell).floor();
    final col = (position.dx / cell).floor();
    if (row < 0 ||
        row >= MatchBoard.side ||
        col < 0 ||
        col >= MatchBoard.side) {
      return null;
    }
    return row * MatchBoard.side + col;
  }

  @override
  Widget build(BuildContext context) {
    final frame = widget.view.frame;
    final duration = _animate
        ? const Duration(milliseconds: 180)
        : Duration.zero;
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF8BC7AE), width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cell = constraints.maxWidth / MatchBoard.side;
              return Listener(
                key: const ValueKey('match-board'),
                behavior: HitTestBehavior.opaque,
                onPointerDown: (details) {
                  if (_pointer != null) return;
                  _pointer = details.pointer;
                  _dragStart = details.localPosition;
                },
                onPointerCancel: (details) {
                  if (details.pointer != _pointer) return;
                  _pointer = null;
                  _dragStart = null;
                },
                onPointerUp: (details) {
                  if (details.pointer != _pointer) return;
                  final start = _dragStart;
                  final end = details.localPosition;
                  _pointer = null;
                  _dragStart = null;
                  if (start == null) return;
                  final from = _cellAt(start, cell);
                  final delta = end - start;
                  if (from == null) return;
                  if (delta.distance < cell * 0.35) {
                    widget.manager.selectCell(from);
                    return;
                  }
                  final to = delta.dx.abs() > delta.dy.abs()
                      ? from + (delta.dx > 0 ? 1 : -1)
                      : from +
                            (delta.dy > 0 ? MatchBoard.side : -MatchBoard.side);
                  widget.manager.swap(from, to);
                },
                // 棋盘内的纵向滑动也是交换，不应被外层滚动视图抢走。
                // 从按下到抬起完整记录位置，快速滑动也不会丢失首段位移。
                child: RawGestureDetector(
                  behavior: HitTestBehavior.opaque,
                  gestures: {
                    EagerGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                          EagerGestureRecognizer
                        >(EagerGestureRecognizer.new, (_) {}),
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        for (var index = 0; index < MatchBoard.cells; index++)
                          Positioned(
                            left: index % MatchBoard.side * cell,
                            top: index ~/ MatchBoard.side * cell,
                            width: cell,
                            height: cell,
                            child: Padding(
                              padding: const EdgeInsets.all(1),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: frame.ice[index] > 0
                                      ? const Color(0xFFADDCF0)
                                            .withValues(alpha: 0.65)
                                      : Colors.white.withValues(
                                          alpha: index.isEven ? 0.16 : 0.08,
                                        ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: frame.ice[index] > 0
                                      ? Border.all(
                                          color: const Color(0xFFDCF7FF),
                                          width: 2,
                                        )
                                      : null,
                                ),
                                child: frame.ice[index] > 0
                                    ? const Align(
                                        alignment: Alignment.bottomRight,
                                        child: Icon(
                                          Icons.ac_unit_rounded,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        for (
                          var index = 0;
                          index < frame.pieces.length;
                          index++
                        )
                          if (frame.pieces[index] case final Piece piece)
                            AnimatedPositioned(
                              key: ValueKey('piece-${piece.id}'),
                              duration: duration,
                              curve: Curves.easeOutCubic,
                              left: index % MatchBoard.side * cell,
                              top: index ~/ MatchBoard.side * cell,
                              width: cell,
                              height: cell,
                              child: Semantics(
                                label:
                                    '${S.matchAnimalNames[piece.kind]} ${index ~/ MatchBoard.side + 1}, ${index % MatchBoard.side + 1}',
                                button: true,
                                onTap: () => widget.manager.selectCell(index),
                                child: AnimatedScale(
                                  scale: frame.clearing.contains(index)
                                      ? 0.45
                                      : 1,
                                  duration: duration,
                                  child: AnimatedOpacity(
                                    opacity: frame.clearing.contains(index)
                                        ? 0.15
                                        : 1,
                                    duration: duration,
                                    child: CustomPaint(
                                      painter: AnimalPiecePainter(
                                        piece: piece,
                                        clock: _clock,
                                        animated: _animate,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ValueListenableBuilder<int?>(
                          valueListenable: widget.manager.selected,
                          builder: (_, selected, __) =>
                              ValueListenableBuilder<(int, int)?>(
                                valueListenable: widget.manager.hint,
                                builder: (_, hint, __) => IgnorePointer(
                                  child: Stack(
                                    children: [
                                      for (final index in {
                                        if (selected != null) selected,
                                        if (hint != null) hint.$1,
                                        if (hint != null) hint.$2,
                                      })
                                        Positioned(
                                          left: index % MatchBoard.side * cell,
                                          top: index ~/ MatchBoard.side * cell,
                                          width: cell,
                                          height: cell,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: const Color(0xFFFFD65B),
                                                width: 3,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }
}
