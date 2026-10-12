import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';

import '../../middle/background_settings.dart';

class HomeBackground extends StatelessWidget {
  final Widget child;

  const HomeBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Uint8List?>(
    valueListenable: BackgroundSettings.instance.image,
    builder: (context, bytes, _) => Stack(
      fit: StackFit.expand,
      children: [
        if (bytes != null) ...[
          Image.memory(
            bytes,
            key: const ValueKey('home-background-image'),
            fit: BoxFit.cover,
            cacheWidth: 1920,
            excludeFromSemantics: true,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.65
                  : 0.55,
            ),
          ),
        ],
        child,
      ],
    ),
  );
}
