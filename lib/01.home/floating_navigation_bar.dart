import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

enum FloatingNavigationBarBackground { translucent, frostedGlass }

/// 悬浮导航栏，通过同一块椭圆背景在标签间连续滑动来指示选中项。
class FloatingNavigationBar extends StatelessWidget {
  const FloatingNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.backgroundStyle = FloatingNavigationBarBackground.translucent,
  }) : assert(destinations.length > 1),
       assert(selectedIndex >= 0 && selectedIndex < destinations.length);

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;
  final FloatingNavigationBarBackground backgroundStyle;

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
    final frosted =
        backgroundStyle == FloatingNavigationBarBackground.frostedGlass;
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

    final surface = DecoratedBox(
      key: const ValueKey('navigation-surface'),
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surface.withValues(
              alpha: frosted ? (dark ? 0.32 : 0.34) : (dark ? 0.72 : 0.78),
            ),
            colors.surface.withValues(
              alpha: frosted ? (dark ? 0.20 : 0.22) : (dark ? 0.62 : 0.68),
            ),
          ],
        ),
        // 边框与选中阴影使用相同的低透明度色调，弱化底板轮廓。
        border: Border.all(
          color: colors.onSurface.withValues(alpha: dark ? 0.12 : 0.08),
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
                  curve: Curves.easeOutCubic,
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? 0.20 : 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                    blurStyle: BlurStyle.outer,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? 0.12 : 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                    blurStyle: BlurStyle.outer,
                  ),
                ],
              ),
              child: ClipRRect(
                key: const ValueKey('navigation-background'),
                borderRadius: radius,
                child: frosted
                    ? BackdropFilter(
                        // 毛玻璃模式保留底下内容的轮廓和色彩。
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
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
