import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:flutter/material.dart';

import '../00.common/config/network_config.dart';
import '../00.common/l10n/l10n.dart';
import '../00.common/l10n/strings.dart';
import '../00.common/model/app_item_type.dart';
import '../00.common/network/protocol/network_room.dart';
import '../00.common/style/theme.dart';
import '../00.common/tool/app_info.dart';
import '../00.common/service/storage_service.dart';
import '../00.common/widget/navigator/notifier_navigator.dart';
import '../00.common/widget/component/chat_component.dart' show MediaFilePicker;

import 'background_settings.dart';
import 'home_manager.dart';
import 'route.dart';
import 'floating_navigation_bar.dart';
import 'player_settings.dart';

class HomePage extends StatefulWidget {
  final HomeManager? manager;
  const HomePage({super.key, this.manager});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeManager _manager;
  int _selectedTabIndex = 0;
  String _appSearchQuery = '';
  List<AppItemType> _recentApps = [];
  bool _changingBackground = false;

  @override
  void initState() {
    super.initState();
    _manager = widget.manager ?? HomeManager();
    _loadRecentApps();
  }

  Future<void> _loadRecentApps() async {
    final list = await StorageService.instance.readList(
      'recent_apps',
      project: '01.home',
    );
    if (!mounted) return;
    setState(() {
      _recentApps = list
          .whereType<String>()
          .map((key) {
            for (final item in AppItemType.values) {
              if (item.name == key) return item;
            }
            return null;
          })
          .whereType<AppItemType>()
          .take(3)
          .toList();
    });
  }

  void _openLocal(AppItemType item) {
    setState(() {
      _recentApps = [
        item,
        ..._recentApps.where((other) => other != item),
      ].take(3).toList();
    });
    StorageService.instance.writeList(
      'recent_apps',
      _recentApps.map((item) => item.name).toList(),
      project: '01.home',
    );
    _manager.routeLocal(item);
  }

  void _quickCreateRoom(AppItemType item) {
    final onlineType = item.onlineType;
    if (onlineType == null) return;

    setState(() => _selectedTabIndex = 1);
    _manager.showCreateRoomDialog(onlineType: onlineType);
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
      appBar: AppBar(
        title: Text([S.appsPage, S.onlinePage, S.settings][_selectedTabIndex]),
      ),
      // 读取 Scaffold 为延伸内容提供的底部避让高度，包含胶囊导航和安全区。
      // 将留白放在各自的滚动视图内部，让内容能够从毛玻璃后方滚过。
      body: Builder(
        builder: (bodyContext) => Column(
          children: [
            NotifierNavigator(navigatorHandler: _manager.pageNavigator),
            Expanded(
              child: _homeBackground(
                IndexedStack(
                  index: _selectedTabIndex,
                  children: [
                    _appsPage(MediaQuery.paddingOf(bodyContext).bottom),
                    _onlinePage(MediaQuery.paddingOf(bodyContext).bottom),
                    _settingsPage(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
          ? null
          : FloatingNavigationBar(
              selectedIndex: _selectedTabIndex,
              onDestinationSelected: (index) =>
                  setState(() => _selectedTabIndex = index),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.widgets_outlined),
                  selectedIcon: const Icon(Icons.widgets),
                  label: S.appsPage,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.lan_outlined),
                  selectedIcon: const Icon(Icons.lan),
                  label: S.onlinePage,
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

  Widget _appsPage(double bottomInset) {
    final all = AppItemType.values
        .where(
          (item) => S
              .roomTypeString(item.name)
              .toLowerCase()
              .contains(_appSearchQuery.toLowerCase()),
        )
        .toList();
    final recent = _recentApps.where(all.contains).toList();
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
          onChanged: (value) => setState(() => _appSearchQuery = value.trim()),
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

  Widget _homeBackground(Widget child) => ValueListenableBuilder<Uint8List?>(
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

  Widget _appCard(AppItemType item) {
    final canPlayOnline = item.onlineType != null;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.gamepad),
        title: Text(S.roomTypeString(item.name)),
        trailing: canPlayOnline
            ? IconButton(
                tooltip: S.quickCreateRoom,
                icon: const Icon(Icons.wifi_tethering),
                onPressed: () => _quickCreateRoom(item),
              )
            : null,
        onTap: () => _openLocal(item),
      ),
    );
  }

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

  Widget _onlinePage(double bottomInset) => ListView(
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
        ? room.server.members.length
        : room.count;
    final onlineType = OnlineItemType.tryFromRoomType(type);
    final isGame = onlineType != null && onlineType != OnlineItemType.onlyChat;
    return Card(
      child: ListTile(
        leading: Icon(isGame ? Icons.gamepad : Icons.forum_outlined),
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
            if (isGame) S.roomTypeString(onlineType.name),
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

  Widget _settingsPage() => ListView(
    padding: EdgeInsets.only(
      top: 8,
      bottom: 8 + MediaQuery.paddingOf(context).bottom,
    ),
    children: [
      _settingsSection(
        context,
        title: S.general,
        children: [
          _defaultNameTile(),
          _languageTile(),
          _themeTile(),
          _backgroundTile(),
        ],
      ),
      _settingsSection(
        context,
        title: S.about,
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(S.version),
            subtitle: Text(AppInfo.isLoaded ? (AppInfo.version ?? '—') : '—'),
          ),
        ],
      ),
    ],
  );

  Widget _defaultNameTile() => ValueListenableBuilder<String>(
    valueListenable: PlayerSettings.instance.defaultName,
    builder: (_, name, __) => ListTile(
      leading: const Icon(Icons.person_outline),
      title: Text(S.defaultPlayerName),
      subtitle: Text(name.isEmpty ? S.enterUserName : name),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => unawaited(_editDefaultName()),
    ),
  );

  Future<void> _editDefaultName() async {
    await PlayerSettings.instance.load();
    if (!mounted) return;

    final current = PlayerSettings.instance.defaultName.value;
    var name = current;
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(S.defaultPlayerName),
          content: TextFormField(
            initialValue: current,
            autofocus: true,
            decoration: InputDecoration(
              labelText: S.userName,
              helperText: S.defaultPlayerNameHint,
            ),
            onChanged: (value) => name = value,
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                PlayerSettings.instance.setDefaultName(name);
              },
              child: Text(S.confirm),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(S.cancel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      ...children.map(
        (child) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: child,
          ),
        ),
      ),
    ],
  );

  Widget _languageTile() => ValueListenableBuilder<AppLocale>(
    valueListenable: LanguageProvider.instance.locale,
    builder: (context, currentLocale, _) => ListTile(
      leading: const Icon(Icons.language),
      title: Text(S.language),
      subtitle: Text(currentLocale == AppLocale.zh ? S.chinese : S.english),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showLanguageDialog(currentLocale),
    ),
  );

  Widget _themeTile() => ValueListenableBuilder<ThemeMode>(
    valueListenable: ThemeProvider.instance.themeMode,
    builder: (context, currentTheme, _) => ListTile(
      leading: const Icon(Icons.palette),
      title: Text(S.theme),
      subtitle: Text(
        currentTheme == ThemeMode.light ? S.themeLight : S.themeDark,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showThemeDialog(currentTheme),
    ),
  );

  Widget _backgroundTile() => ValueListenableBuilder<Uint8List?>(
    valueListenable: BackgroundSettings.instance.image,
    builder: (_, bytes, __) => ListTile(
      leading: const Icon(Icons.wallpaper_outlined),
      title: Text(S.background),
      subtitle: Text(S.homeBackgroundHint),
      trailing: _changingBackground
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : bytes == null
          ? const Icon(Icons.chevron_right)
          : IconButton(
              tooltip: S.restoreDefaultBackground,
              icon: const Icon(Icons.restore),
              onPressed: () => unawaited(_changeBackground(clear: true)),
            ),
      onTap: _changingBackground ? null : () => unawaited(_changeBackground()),
    ),
  );

  Future<void> _changeBackground({bool clear = false}) async {
    if (_changingBackground) return;
    setState(() => _changingBackground = true);
    try {
      final bytes = clear ? null : await MediaFilePicker.pickImage();
      if (!mounted || (!clear && bytes == null)) return;
      if (bytes != null && bytes.length > BackgroundSettings.maxImageBytes) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.backgroundImageTooLarge)));
        return;
      }
      await BackgroundSettings.instance.setImage(bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.backgroundImageFailed)));
      }
    } finally {
      if (mounted) setState(() => _changingBackground = false);
    }
  }

  void _showThemeDialog(ThemeMode currentTheme) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(S.theme),
        children: [
          RadioGroup<ThemeMode>(
            groupValue: currentTheme,
            onChanged: (value) async {
              if (value == null) return;
              Navigator.pop(dialogContext);
              await ThemeProvider.instance.setThemeMode(value);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<ThemeMode>(
                  title: Text(S.themeLight),
                  value: ThemeMode.light,
                ),
                RadioListTile<ThemeMode>(
                  title: Text(S.themeDark),
                  value: ThemeMode.dark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(AppLocale currentLocale) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(S.language),
        children: [
          RadioGroup<AppLocale>(
            groupValue: currentLocale,
            onChanged: (value) async {
              if (value == null) return;
              Navigator.pop(dialogContext);
              await LanguageProvider.instance.setLocale(value);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<AppLocale>(
                  title: Text(S.chinese),
                  value: AppLocale.zh,
                ),
                RadioListTile<AppLocale>(
                  title: Text(S.english),
                  value: AppLocale.en,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
