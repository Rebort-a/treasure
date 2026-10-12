import 'package:flutter/material.dart';

import '../../../00.common/l10n/strings.dart';
import '../../../00.common/model/app_item_type.dart';
import '../../middle/home_state.dart';
import '../widgets/home_heading.dart';

class HomeAppsPage extends StatelessWidget {
  final HomeState state;
  final ValueChanged<AppItemType> onOpenApp;
  final ValueChanged<AppItemType> onCreateRoom;

  const HomeAppsPage({
    super.key,
    required this.state,
    required this.onOpenApp,
    required this.onCreateRoom,
  });

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: state.searchQuery,
    child: TextField(
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: S.searchApps,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: const OutlineInputBorder(),
      ),
      onChanged: (value) => state.searchQuery.value = value.trim(),
    ),
    builder: (context, query, searchField) =>
        ValueListenableBuilder<List<AppItemType>>(
          valueListenable: state.recentApps,
          builder: (context, recentApps, _) {
            final all = AppItemType.values
                .where(
                  (item) => S
                      .roomTypeString(item.name)
                      .toLowerCase()
                      .contains(query.toLowerCase()),
                )
                .toList();
            final recent = recentApps.where(all.contains).toList();
            return ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                searchField!,
                if (recent.isNotEmpty) ...[
                  HomeHeading(S.recentApps),
                  ...recent.map(_appCard),
                ],
                HomeHeading('${S.allApps} (${all.length})'),
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
          },
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
                onPressed: () => onCreateRoom(item),
              )
            : null,
        onTap: () => onOpenApp(item),
      ),
    );
  }
}
