import 'package:flutter/material.dart';

/// 在 PageView 中保留已访问标签页的状态，延续原 IndexedStack 的状态保留行为。
class HomeTabPage extends StatefulWidget {
  final Widget child;

  const HomeTabPage({super.key, required this.child});

  @override
  State<HomeTabPage> createState() => _HomeTabPageState();
}

class _HomeTabPageState extends State<HomeTabPage>
    with AutomaticKeepAliveClientMixin<HomeTabPage> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
