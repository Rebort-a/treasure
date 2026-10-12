import 'dart:async';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

import '../../00.common/l10n/strings.dart';
import '../../00.common/model/app_item_type.dart';
import '../../00.common/widget/navigator/notifier_navigator.dart';
import '../middle/home_state.dart';
import 'home_manager.dart';
import 'pages/apps_page.dart';
import 'pages/online_page.dart';
import 'pages/settings_page.dart';
import 'widgets/floating_navigation_bar.dart';
import 'widgets/home_background.dart';
import 'widgets/home_tab_page.dart';

/// 首页入口，仅负责页面组合、切换与所持资源的生命周期。
class HomePage extends StatefulWidget {
  // 仅供测试注入；首页接管其生命周期，并在卸载时释放。
  final HomeManager? manager;

  const HomePage({super.key, this.manager});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeManager _manager;
  final HomeState _state = HomeState();
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _manager = widget.manager ?? HomeManager();
    unawaited(_state.loadRecentApps());
  }

  void _openLocal(AppItemType item) {
    unawaited(_state.rememberApp(item));
    _manager.routeLocal(item);
  }

  void _quickCreateRoom(AppItemType item) {
    final onlineType = item.onlineType;
    if (onlineType == null) return;
    _selectTab(1);
    _manager.showCreateRoomDialog(onlineType: onlineType);
  }

  void _updateSelectedTab(int index) {
    if (_state.selectedTab.value == index) return;
    FocusScope.of(context).unfocus();
    _state.selectedTab.value = index;
  }

  void _selectTab(int index) {
    _updateSelectedTab(index);
    _pageController.jumpToPage(index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _state.dispose();
    _manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBody: true,
    appBar: AppBar(
      title: ValueListenableBuilder<int>(
        valueListenable: _state.selectedTab,
        builder: (_, index, __) =>
            Text([S.appsPage, S.onlinePage, S.settings][index]),
      ),
    ),
    // 各标签页自行读取 Scaffold 提供的底部避让，内容仍可从毛玻璃后方滚过。
    body: Column(
      children: [
        NotifierNavigator(navigatorHandler: _manager.pageNavigator),
        Expanded(
          child: HomeBackground(
            child: PageView(
              key: const ValueKey('home-pages'),
              controller: _pageController,
              onPageChanged: _updateSelectedTab,
              // 仅为首页翻页开放鼠标拖动。
              scrollBehavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  ...ScrollConfiguration.of(context).dragDevices,
                  PointerDeviceKind.mouse,
                },
              ),
              children: [
                HomeTabPage(
                  child: HomeAppsPage(
                    state: _state,
                    onOpenApp: _openLocal,
                    onCreateRoom: _quickCreateRoom,
                  ),
                ),
                HomeTabPage(child: HomeOnlinePage(manager: _manager)),
                HomeTabPage(child: HomeSettingsPage(state: _state)),
              ],
            ),
          ),
        ),
      ],
    ),
    bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
        ? null
        : ValueListenableBuilder<int>(
            valueListenable: _state.selectedTab,
            builder: (_, index, __) => FloatingNavigationBar(
              selectedIndex: index,
              onDestinationSelected: _selectTab,
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
          ),
  );
}
