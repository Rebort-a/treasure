import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../00.common/config/network_config.dart';
import '../00.common/network/network_room.dart';
import '../00.common/style/theme.dart';
import '../00.common/widget/navigator/notifier_navigator.dart';
import '../00.common/l10n/strings.dart';
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
  List<CreatedRoomInfo> get _createdRooms => _homeManager.createdRooms.value;
  List<RoomInfo> get _othersRooms => _homeManager.othersRooms.value;

  bool _createdExpanded = true;
  bool _othersExpanded = true;
  bool _localExpanded = true;

  @override
  void initState() {
    super.initState();
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
    setState(() {});
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
        ..._buildSection<CreatedRoomInfo>(
          list: _createdRooms,
          expanded: _createdExpanded,
          toggle: () => setState(() => _createdExpanded = !_createdExpanded),
          title: S.createdRooms,
          trailing: _createdRooms.length > 1
              ? TextButton(
                  onPressed: _homeManager.stopAllCreatedRooms,
                  child: Text(S.stopAll),
                )
              : null,
          buildItem: (room, idx) => _buildRoomCard(
            room: room,
            actions: [
              TextButton(
                onPressed: () => _homeManager.showJoinRoomDialog(room),
                child: Text(S.join),
              ),
              TextButton(
                onPressed: () => _homeManager.stopCreatedRoom(idx),
                child: Text(S.stop),
              ),
            ],
          ),
        ),

        // ---- 其他房间 ----
        ..._buildSection<RoomInfo>(
          list: _othersRooms,
          expanded: _othersExpanded,
          toggle: () => setState(() => _othersExpanded = !_othersExpanded),
          title: S.otherRooms,
          buildItem: (room, _) => _buildRoomCard(
            room: room,
            actions: [
              TextButton(
                onPressed: () => _homeManager.showJoinRoomDialog(room),
                child: Text(S.join),
              ),
            ],
          ),
        ),

        // ---- 本地应用 ----
        ..._buildSection<LocalItemType>(
          list: LocalItemType.values.toList(),
          expanded: _localExpanded,
          toggle: () => setState(() => _localExpanded = !_localExpanded),
          title: S.local,
          isLocalStatic: true,
          buildLocalItem: (type, _) => Card(
            child: ListTile(
              leading: const Icon(Icons.gamepad),
              title: Text(S.roomTypeString(type.toString().split('.').last)),
              onTap: () => _homeManager.routeLocal(type),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoomCard({
    required RoomInfo room,
    required List<Widget> actions,
  }) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.home),
        title: Text(
          "${room.name} ${S.roomTypeString(NetItemType.values[room.type].name)}",
        ),
        subtitle: Text('${room.address}:${room.port}'),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: actions),
      ),
    );
  }

  List<Widget> _buildSection<T>({
    required List<T> list,
    required bool expanded,
    required VoidCallback toggle,
    required String title,
    Widget? trailing,
    Widget Function(T item, int index)? buildItem,
    Widget Function(T item, int index)? buildLocalItem,
    bool isLocalStatic = false,
  }) {
    if (list.isEmpty && !isLocalStatic) return const [];

    return [
      SliverPersistentHeader(
        pinned: true,
        delegate: _PinnedHeaderDelegate(
          height: 48,
          child: _buildHeader(
            expanded: expanded,
            toggle: toggle,
            title: title,
            trailing: trailing,
          ),
        ),
      ),
      if (expanded)
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, idx) => isLocalStatic
                ? buildLocalItem!(list[idx], idx)
                : buildItem!(list[idx], idx),
            childCount: list.length,
          ),
        ),
    ];
  }

  Widget _buildHeader({
    required bool expanded,
    required VoidCallback toggle,
    required String title,
    Widget? trailing,
  }) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListTile(
        dense: true,
        leading: ExpandIcon(isExpanded: expanded, onPressed: (_) => toggle()),
        title: Text(title, style: globalTheme.textTheme.titleLarge),
        trailing: trailing,
      ),
    );
  }
}

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
