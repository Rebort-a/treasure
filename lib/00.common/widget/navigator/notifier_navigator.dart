import 'package:flutter/material.dart';

import '../../tool/notifiers.dart';

class NotifierNavigator extends StatefulWidget {
  final AlwaysNotifier<void Function(BuildContext)> navigatorHandler;

  const NotifierNavigator({super.key, required this.navigatorHandler});

  @override
  State<NotifierNavigator> createState() => _NotifierNavigatorState();
}

class _NotifierNavigatorState extends State<NotifierNavigator> {
  static void _empty(BuildContext _) {}

  final List<void Function(BuildContext)> _pending = [];
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    widget.navigatorHandler.addListener(_takeCommand);
    _takeCommand();
  }

  @override
  void didUpdateWidget(NotifierNavigator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.navigatorHandler, widget.navigatorHandler)) return;
    oldWidget.navigatorHandler.removeListener(_takeCommand);
    _pending.clear();
    widget.navigatorHandler.addListener(_takeCommand);
    _takeCommand();
  }

  void _takeCommand() {
    final command = widget.navigatorHandler.value;
    if (identical(command, _empty)) return;
    _pending.add(command);
    // 执行前消费命令，避免清空操作重复调度，也避免覆盖回调中新发出的命令。
    widget.navigatorHandler.value = _empty;
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final commands = List.of(_pending);
      _pending.clear();
      for (final command in commands) {
        if (!mounted) return;
        // 路由退出动画期间组件仍然 mounted，但已不能再操作当前导航栈。
        // 每条命令前都检查，避免一次 pop 后的重复或迟到命令把下层页面也弹出。
        if (ModalRoute.of(context)?.isActive == false) return;
        command(context);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    widget.navigatorHandler.removeListener(_takeCommand);
    _pending.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
