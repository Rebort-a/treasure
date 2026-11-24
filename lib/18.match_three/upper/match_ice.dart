import 'package:material_ui/material_ui.dart';

import '../base/match_board.dart';
import '../middle/match_manager.dart';

class MatchIce extends StatelessWidget {
  final int layers;

  const MatchIce({super.key, required this.layers});

  @override
  Widget build(BuildContext context) {
    final thick = layers == 2;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: thick ? const Color(0xB25EADD6) : const Color(0x859DDBF2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xD9D9F5FF),
            width: thick ? 2.5 : 1.5,
          ),
        ),
        child: thick
            ? const Padding(
                padding: EdgeInsets.all(4),
                child: DecoratedBox(
                  key: ValueKey('match-thick-ice'),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    border: Border.fromBorderSide(
                      BorderSide(color: Color(0xB2D9F5FF)),
                    ),
                  ),
                  child: FractionallySizedBox(
                    widthFactor: 0.45,
                    heightFactor: 0.45,
                    alignment: Alignment.topRight,
                    child: FittedBox(
                      child: Icon(
                        Icons.ac_unit_rounded,
                        color: Color(0xE6F3FCFF),
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

class MatchIceSpread extends StatelessWidget {
  final BoardFrame frame;

  const MatchIceSpread({super.key, required this.frame});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MatchManager.iceSpreadDuration,
      builder: (_, progress, _) => CustomPaint(
        key: const ValueKey('match-ice-spread'),
        painter: _IceSpreadPainter(frame.spreadingIce, progress),
      ),
    ),
  );
}

class _IceSpreadPainter extends CustomPainter {
  final Map<int, int> sources;
  final double progress;

  const _IceSpreadPainter(this.sources, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / MatchBoard.side;
    Offset center(int index) => Offset(
      (index % MatchBoard.side + 0.5) * cell,
      (index ~/ MatchBoard.side + 0.5) * cell,
    );
    final travel = Curves.easeOut.transform((progress / 0.7).clamp(0.0, 1.0));
    final paint = Paint()
      ..color = const Color(0xFFE6FAFF).withValues(alpha: 0.9 * (1 - progress))
      ..strokeCap = StrokeCap.round
      ..strokeWidth = cell * 0.09;
    for (final entry in sources.entries) {
      final source = center(entry.value);
      final target = center(entry.key);
      final tip = Offset.lerp(source, target, travel)!;
      canvas.drawLine(Offset.lerp(source, tip, 0.35)!, tip, paint);
      canvas.drawCircle(tip, cell * (0.09 + travel * 0.12), paint);
    }
  }

  @override
  bool shouldRepaint(_IceSpreadPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.sources != sources;
}
