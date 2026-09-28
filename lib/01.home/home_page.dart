import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../00.common/config/network_config.dart';
import '../00.common/l10n/strings.dart';
import '../00.common/network/network_room.dart';
import '../00.common/tool/storage_service.dart';
import '../00.common/widget/navigator/notifier_navigator.dart';
import 'floating_navigation_bar.dart';
import 'home_manager.dart';
import 'route.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  final HomeManager? manager;
  const HomePage({super.key, this.manager});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeManager _manager;
  int _tab = 0;
  String _query = '';
  List<LocalItemType> _recent = [];

  @override
  void initState() {
    super.initState();
    _manager = widget.manager ?? HomeManager();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final list = await StorageService.instance.readList('recent_apps');
    if (!mounted) return;
    setState(() {
      _recent = list
          .whereType<String>()
          .map((key) {
            for (final item in LocalItemType.values) {
              if (item.name == key) return item;
            }
            return null;
          })
          .whereType<LocalItemType>()
          .take(3)
          .toList();
    });
  }

  void _openLocal(LocalItemType item) {
    setState(() {
      _recent = [
        item,
        ..._recent.where((other) => other != item),
      ].take(3).toList();
    });
    StorageService.instance.writeList(
      'recent_apps',
      _recent.map((item) => item.name).toList(),
    );
    _manager.routeLocal(item);
  }

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: Text([S.local, S.network, S.settings][_tab])),
      // 读取 Scaffold 为延伸内容提供的底部避让高度，包含胶囊导航和安全区。
      // 将留白放在各自的滚动视图内部，让内容能够从毛玻璃后方滚过。
      body: Builder(
        builder: (bodyContext) => Column(
          children: [
            NotifierNavigator(navigatorHandler: _manager.pageNavigator),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  _localPage(MediaQuery.paddingOf(bodyContext).bottom),
                  _networkPage(MediaQuery.paddingOf(bodyContext).bottom),
                  const SettingsPage(embedded: true),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
          ? null
          : FloatingNavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (index) => setState(() => _tab = index),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.widgets_outlined),
                  selectedIcon: const Icon(Icons.widgets),
                  label: S.local,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.lan_outlined),
                  selectedIcon: const Icon(Icons.lan),
                  label: S.network,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings),
                  label: S.settings,
                ),
              ],
            ),
    );
  }

  Widget _localPage(double bottomInset) {
    final all = LocalItemType.values
        .where(
          (item) => S
              .roomTypeString(item.name)
              .toLowerCase()
              .contains(_query.toLowerCase()),
        )
        .toList();
    final recent = _recent.where(all.contains).toList();
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      children: [
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: S.searchApps,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: const OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => _query = value.trim()),
        ),
        if (recent.isNotEmpty) ...[
          _heading(S.recentApps),
          ...recent.map(_appCard),
        ],
        _heading('${S.allApps} (${all.length})'),
        ...all.map(_appCard),
        if (all.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(S.noAppsFound),
            ),
          ),
      ],
    );
  }

  Widget _appCard(LocalItemType item) => Card(
    child: ListTile(
      leading: const Icon(Icons.sports_esports_outlined),
      title: Text(S.roomTypeString(item.name)),
      trailing: NetItemType.values.any((net) => net.name == item.name)
          ? const Icon(Icons.wifi_tethering)
          : null,
      onTap: () => _openLocal(item),
    ),
  );

  Widget _heading(String title, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (trailing != null) trailing,
      ],
    ),
  );

  Widget _networkPage(double bottomInset) => ListView(
    padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (!kIsWeb)
            FilledButton.icon(
              onPressed: _manager.showCreateRoomDialog,
              icon: const Icon(Icons.add_home_outlined),
              label: Text(S.createRoom),
            ),
          if (!kIsWeb || networkMode == NetworkMode.webSocket)
            OutlinedButton.icon(
              onPressed: _manager.showJoinByIpDialog,
              icon: const Icon(Icons.add_link),
              label: Text(S.joinByIp),
            ),
        ],
      ),
      ValueListenableBuilder<List<CreatedRoomInfo>>(
        valueListenable: _manager.createdRooms,
        builder: (_, rooms, __) => Column(
          children: [
            _heading(
              S.createdRooms,
              trailing: rooms.length > 1
                  ? TextButton(
                      onPressed: _manager.stopAllCreatedRooms,
                      child: Text(S.stopAll),
                    )
                  : null,
            ),
            if (rooms.isEmpty) ListTile(title: Text(S.noRooms)),
            for (var index = 0; index < rooms.length; index++)
              _roomCard(
                rooms[index],
                onStop: () => _manager.stopCreatedRoom(index),
              ),
          ],
        ),
      ),
      ValueListenableBuilder<List<RoomInfo>>(
        valueListenable: _manager.othersRooms,
        builder: (_, rooms, __) => Column(
          children: [
            _heading(S.otherRooms),
            if (rooms.isEmpty) ListTile(title: Text(S.noRooms)),
            ...rooms.map((room) => _roomCard(room)),
          ],
        ),
      ),
    ],
  );

  Widget _roomCard(RoomInfo room, {VoidCallback? onStop}) {
    final type = room is CreatedRoomInfo ? room.server.roomType : room.type;
    final count = room is CreatedRoomInfo
        ? room.server.session.count
        : room.count;
    final isGame = type > RoomInfo.chatType && type < NetItemType.values.length;
    return Card(
      child: ListTile(
        leading: Icon(
          isGame ? Icons.sports_esports_outlined : Icons.forum_outlined,
        ),
        title: Row(
          children: [
            if (room.hasPassword) ...[
              const Icon(Icons.lock_outline, size: 16),
              const SizedBox(width: 6),
            ],
            Expanded(child: Text('${room.name} ($count)')),
          ],
        ),
        subtitle: Text(
          [
            if (isGame) S.roomTypeString(NetItemType.values[type].name),
            '${room.address}:${room.port}',
          ].join(' · '),
        ),
        onTap: () => _manager.showJoinRoomDialog(room),
        trailing: onStop == null
            ? const Icon(Icons.chevron_right)
            : IconButton(
                icon: const Icon(Icons.stop_circle_outlined),
                tooltip: S.stop,
                onPressed: onStop,
              ),
      ),
    );
  }
}
