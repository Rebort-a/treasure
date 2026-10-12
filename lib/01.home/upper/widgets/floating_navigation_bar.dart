import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

/// 导航栏底板材质，按表现力从高到低排列，
/// 对应「液态玻璃 → 毛玻璃 → 模拟玻璃 → 半透明」的能力降级链。
enum NavigationBarType {
  /// 液态玻璃：强模糊 + 高光渐变 + 灰色细线描边 + 回弹动效，
  /// 观感最接近 iOS 26 液态玻璃，GPU 开销最高。
  liquidGlass,

  /// 毛玻璃：轻模糊，保留底下内容的轮廓与色彩（即原 frostedGlass，观感不变）。
  frostedGlass,

  /// 模拟玻璃：不做实时模糊，用渐变高光与描边画出玻璃质感，适合低端机型。
  simulatedGlass,

  /// 半透明：仅一层半透明底板，最轻量（即原 translucent，观感不变）。
  translucent;

  /// 是否需要 BackdropFilter 实时模糊底图。
  bool get usesBackdropFilter => switch (this) {
    liquidGlass || frostedGlass => true,
    simulatedGlass || translucent => false,
  };

  /// 实时模糊强度；不实时模糊的档位不会用到。
  double get blurSigma => switch (this) {
    liquidGlass => 16.0,
    frostedGlass => 5.0,
    _ => 0.0,
  };

  /// 按平台建议的默认档位：iOS/macOS 走液态玻璃，Web/Android 走模拟玻璃。
  static NavigationBarType get platformDefault {
    if (kIsWeb) return simulatedGlass;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => liquidGlass,
      _ => simulatedGlass,
    };
  }
}

/// 悬浮导航栏，通过同一块椭圆背景在标签间连续滑动来指示选中项。
class FloatingNavigationBar extends StatelessWidget {
  const FloatingNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.backgroundStyle = NavigationBarType.simulatedGlass,
  }) : assert(destinations.length > 1),
       assert(selectedIndex >= 0 && selectedIndex < destinations.length);

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;
  final NavigationBarType backgroundStyle;

  static const _iconSize = 24.0;
  static const _labelFontSize = 12.0;
  static const _labelHeight = 1.2;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 360);
    const radius = BorderRadius.all(Radius.circular(100));
    // 默认保持原有高度；系统放大字体时，为图标、标签及上下留白同步扩展底板和指示层。
    final contentHeight =
        (_iconSize +
                2 +
                MediaQuery.textScalerOf(context).scale(_labelFontSize) *
                    _labelHeight +
                6)
            .ceilToDouble()
            .clamp(48.0, double.infinity);

    // 四档材质的底板透明度（顶、底）：越靠后的降级档位越「实」，
    // 因为没有实时模糊兜底，需要更高的不透明度保证图标和文字可读。
    final (topAlpha, bottomAlpha) = switch (backgroundStyle) {
      NavigationBarType.liquidGlass => (dark ? 0.26 : 0.28, dark ? 0.14 : 0.16),
      NavigationBarType.frostedGlass => (
        dark ? 0.32 : 0.34,
        dark ? 0.20 : 0.22,
      ),
      NavigationBarType.simulatedGlass => (
        dark ? 0.58 : 0.62,
        dark ? 0.46 : 0.50,
      ),
      NavigationBarType.translucent => (dark ? 0.80 : 0.85, dark ? 0.70 : 0.75),
    };

    // 高光渐变：液态玻璃最强、模拟玻璃次之；画在内容之上，模拟玻璃表面掠过的反光。
    final Gradient? sheen = switch (backgroundStyle) {
      NavigationBarType.liquidGlass => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0.0, 0.52, 1.0],
        colors: [
          Colors.white.withValues(alpha: dark ? 0.24 : 0.30),
          Colors.white.withValues(alpha: dark ? 0.02 : 0.04),
          Colors.white.withValues(alpha: dark ? 0.10 : 0.16),
        ],
      ),
      NavigationBarType.simulatedGlass => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0.0, 0.52, 1.0],
        colors: [
          Colors.white.withValues(alpha: dark ? 0.14 : 0.18),
          Colors.white.withValues(alpha: dark ? 0.02 : 0.03),
          Colors.white.withValues(alpha: dark ? 0.06 : 0.09),
        ],
      ),
      _ => null,
    };

    final surface = Container(
      key: const ValueKey('navigation-surface'),
      // 半透明中性灰融入玻璃底板，保留一逻辑像素宽度，避免过细描边显得断续。
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        gradient: sheen,
        border: Border.all(
          color: Colors.grey.withValues(alpha: dark ? 0.45 : 0.40),
          width: 1,
        ),
      ),
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surface.withValues(alpha: topAlpha),
            colors.surface.withValues(alpha: bottomAlpha),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: SizedBox(
          height: contentHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                child: AnimatedAlign(
                  alignment: AlignmentDirectional(
                    -1 + 2 * selectedIndex / (destinations.length - 1),
                    0,
                  ),
                  duration: duration,
                  // 液态玻璃档位用带一点过冲的曲线，模拟「液体流动」的回弹感。
                  curve: backgroundStyle == NavigationBarType.liquidGlass
                      ? Curves.easeOutBack
                      : Curves.easeOutCubic,
                  child: FractionallySizedBox(
                    widthFactor: 1 / destinations.length,
                    heightFactor: 1,
                    child: Center(
                      // 指示层横向略微拉长，上下保留 4 像素间距，不铺满标签点击区域。
                      child: SizedBox(
                        width: 66,
                        height: contentHeight,
                        child: DecoratedBox(
                          key: const ValueKey('navigation-selection'),
                          decoration: BoxDecoration(
                            borderRadius: radius,
                            color: colors.onSurface.withValues(
                              alpha: dark ? 0.12 : 0.08,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Material(
                type: MaterialType.transparency,
                child: Row(
                  children: [
                    for (var index = 0; index < destinations.length; index++)
                      Expanded(child: _destination(context, index)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                // 仅保留居中的外阴影，避免偏移轮廓透过半透明底板形成双层胶囊。
                // 液态玻璃悬浮感更强，阴影随之放大一档。
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? 0.20 : 0.08),
                    blurRadius: backgroundStyle == NavigationBarType.liquidGlass
                        ? 24
                        : 18,
                    blurStyle: BlurStyle.outer,
                  ),
                ],
              ),
              child: ClipRRect(
                key: const ValueKey('navigation-background'),
                borderRadius: radius,
                child: backgroundStyle.usesBackdropFilter
                    ? BackdropFilter(
                        // 毛玻璃/液态玻璃保留底下内容的轮廓和色彩，液态玻璃模糊更强。
                        filter: ImageFilter.blur(
                          sigmaX: backgroundStyle.blurSigma,
                          sigmaY: backgroundStyle.blurSigma,
                        ),
                        child: surface,
                      )
                    : surface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _destination(BuildContext context, int index) {
    final destination = destinations[index];
    final selected = index == selectedIndex;
    final colors = Theme.of(context).colorScheme;
    final color = selected ? colors.primary : colors.onSurfaceVariant;
    return Semantics(
      key: ValueKey('navigation-destination-$index'),
      selected: selected,
      button: true,
      label: destination.label,
      child: Tooltip(
        message: destination.label,
        excludeFromSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          // 禁用目标标签的按压、悬停水波纹，避免滑动背景抵达前出现第二块阴影。
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          onTap: () => onDestinationSelected(index),
          child: Builder(
            builder: (context) {
              // 键盘导航保留细边框提示，不使用会与选中背景混淆的填充阴影。
              final focused =
                  Focus.of(context).hasFocus &&
                  FocusManager.instance.highlightMode ==
                      FocusHighlightMode.traditional;
              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  border: focused
                      ? Border.all(color: colors.primary, width: 1.5)
                      : null,
                ),
                child: ExcludeSemantics(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconTheme(
                            data: IconThemeData(size: _iconSize, color: color),
                            child: selected
                                ? destination.selectedIcon ?? destination.icon
                                : destination.icon,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            destination.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: color,
                                  fontSize: _labelFontSize,
                                  height: _labelHeight,
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                          ),
                        ],
                      ),
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
}
