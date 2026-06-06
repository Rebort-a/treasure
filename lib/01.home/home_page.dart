import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../00.common/config/network_config.dart';
import '../00.common/network/network_room.dart';
import '../00.common/style/theme.dart';
import '../00.common/widget/notifier_navigator.dart';
import '../l10n/strings.dart';
import 'home_manager.dart';
import 'route.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _homeManager = HomeManager();

  bool _localExpanded = true;
  bool _createdExpanded = true;
  bool _othersExpanded = true;

  List<CreatedRoomInfo> _createdRooms = [];
  List<RoomInfo> _othersRooms = [];

  static const double _headerHeight = 48.0;

  @override
  void initState() {
    super.initState();
    _createdRooms = _homeManager.createdRooms.value;
    _othersRooms = _homeManager.othersRooms.value;
    _homeManager.createdRooms.addListener(_onRoomsChanged);
    _homeManager.othersRooms.addListener(_onRoomsChanged);
  }

  @override
  void dispose() {
    _homeManager.createdRooms.removeListener(_onRoomsChanged);
    _homeManager.othersRooms.removeListener(_onRoomsChanged);
    _homeManager.dispose();
    super.dispose();
  }

  void _onRoomsChanged() {
    setState(() {
      _createdRooms = _homeManager.createdRooms.value;
      _othersRooms = _homeManager.othersRooms.value;
    });
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: _buildAppBar(), body: _buildBody());

  AppBar _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.settings_outlined),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsPage()),
        ),
      ),
      actions: [
        if (!kIsWeb || networkMode == NetworkMode.webSocket)
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: S.joinByIp,
            onPressed: _homeManager.showJoinByIpDialog,
          ),
        if (!kIsWeb)
          IconButton(
            icon: const Icon(Icons.add_home_rounded),
            tooltip: S.createRoom,
            onPressed: _homeManager.showCreateRoomDialog,
          ),
      ],
    );
  }

  Widget _buildBody() {
    return CustomScrollView(
      slivers: [
        // 导航通知器
        SliverToBoxAdapter(
          child: NotifierNavigator(
            navigatorHandler: _homeManager.pageNavigator,
          ),
        ),

        // ---- 创建的房间 ----
        if (_createdRooms.isNotEmpty) ...[
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedHeaderDelegate(
              height: _headerHeight,
              child: _buildHeader(
                expanded: _createdExpanded,
                onToggle: () =>
                    setState(() => _createdExpanded = !_createdExpanded),
                title: S.createdRooms,
                trailing: _createdRooms.length > 1
                    ? TextButton(
                        onPressed: _homeManager.stopAllCreatedRooms,
                        child: Text(S.stopAll),
                      )
                    : null,
              ),
            ),
          ),
          if (_createdExpanded)
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final room = _createdRooms[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.home),
                    title: Text(
                      "${room.name} ${S.netGameName(NetItemType.values[room.type].toString().split('.').last)}",
                    ),
                    subtitle: Text('${room.address}:${room.port}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () =>
                              _homeManager.showJoinRoomDialog(room),
                          child: Text(S.join),
                        ),
                        TextButton(
                          onPressed: () => _homeManager.stopCreatedRoom(index),
                          child: Text(S.stop),
                        ),
                      ],
                    ),
                  ),
                );
              }, childCount: _createdRooms.length),
            ),
        ],

        // ---- 其他房间 ----
        if (_othersRooms.isNotEmpty) ...[
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedHeaderDelegate(
              height: _headerHeight,
              child: _buildHeader(
                expanded: _othersExpanded,
                onToggle: () =>
                    setState(() => _othersExpanded = !_othersExpanded),
                title: S.otherRooms,
              ),
            ),
          ),
          if (_othersExpanded)
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final room = _othersRooms[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.home),
                    title: Text(
                      "${room.name} ${S.netGameName(NetItemType.values[room.type].toString().split('.').last)}",
                    ),
                    subtitle: Text('${room.address}:${room.port}'),
                    trailing: TextButton(
                      onPressed: () => _homeManager.showJoinRoomDialog(room),
                      child: Text(S.join),
                    ),
                  ),
                );
              }, childCount: _othersRooms.length),
            ),
        ],

        // ---- 本地游戏 ----
        SliverPersistentHeader(
          pinned: true,
          delegate: _PinnedHeaderDelegate(
            height: _headerHeight,
            child: _buildHeader(
              expanded: _localExpanded,
              onToggle: () => setState(() => _localExpanded = !_localExpanded),
              title: S.local,
            ),
          ),
        ),
        if (_localExpanded)
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final type = LocalItemType.values[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.gamepad),
                  title: Text(S.localGameName(type.toString().split('.').last)),
                  onTap: () => _homeManager.routeLocal(type),
                ),
              );
            }, childCount: LocalItemType.values.length),
          ),
      ],
    );
  }

  Widget _buildHeader({
    required bool expanded,
    required VoidCallback onToggle,
    required String title,
    Widget? trailing,
  }) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListTile(
        dense: true,
        leading: ExpandIcon(isExpanded: expanded, onPressed: (_) => onToggle()),
        title: Text(title, style: globalTheme.textTheme.titleLarge),
        trailing: trailing,
      ),
    );
  }
}

/// 顶层 pinned header delegate，不嵌套在 SliverMainAxisGroup 内
class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  _PinnedHeaderDelegate({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _PinnedHeaderDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}
