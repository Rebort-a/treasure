import 'package:flutter/material.dart';

import 'dialog.dart';
import 'prop_icon.dart';

import '../../00.common/l10n/strings.dart';
import '../middle/prop.dart';
import '../middle/player.dart';

class PackagePage extends StatefulWidget {
  final NormalPlayer player;
  final VoidCallback? onReturnHome;

  const PackagePage({super.key, required this.player, this.onReturnHome});

  @override
  State<PackagePage> createState() => _PackagePageState();
}

class _PackagePageState extends State<PackagePage> {
  MapProp _selectedItem = PropCollection.emptyItem;

  void _onItemTap(MapProp item) {
    setState(() {
      _selectedItem = item;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.backpack),
        centerTitle: true,
        backgroundColor: Colors.brown[100],
      ),
      backgroundColor: Colors.brown[800],
      body: Column(
        children: [
          _buildGoldDisplay(),
          _buildInventoryGrid(),
          _buildSelectedItemInfo(),
        ],
      ),
    );
  }

  Widget _buildGoldDisplay() {
    return Container(
      margin: const EdgeInsets.all(8.0),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.brown[100],
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Text(S.coinCount(widget.player.money))],
      ),
    );
  }

  Widget _buildInventoryGrid() {
    // 过滤出数量大于0的物品
    final filteredItems = widget.player.props.values.where(
      (item) => item.count > 0,
    );

    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(8.0),
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.brown[100],
          border: Border.all(color: Colors.black, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: GridView.count(
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          padding: const EdgeInsets.all(10),
          children: List.generate(16, (index) {
            final item = filteredItems.length > index
                ? filteredItems.elementAt(index)
                : null;
            return _buildItemTile(item);
          }),
        ),
      ),
    );
  }

  Widget _buildSelectedItemInfo() {
    return Visibility(
      visible: _selectedItem.count > 0,
      child: Container(
        margin: const EdgeInsets.all(8.0),
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.brown[100],
          border: Border.all(color: Colors.black, width: 2),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(S.itemName(_selectedItem.name)),
                Text(_selectedItem.description),
              ],
            ),
            ElevatedButton(
              onPressed: _selectedItem.count > 0 ? _useSelectedItem : null,
              child: Text(S.use),
            ),
          ],
        ),
      ),
    );
  }

  void _useSelectedItem() {
    final item = _selectedItem;
    if (item.effect == PropEffect.none) return;
    if (item.effect == PropEffect.returnHome) {
      final returnHome = widget.onReturnHome;
      if (returnHome == null || !item.consume()) return;
      returnHome();
      Navigator.pop(context);
      return;
    }
    ElementalDialog.showSelectEnergyDialog(
      context: context,
      elemental: widget.player,
      available: false,
      onSelected: (target) {
        if (!mounted) return;
        setState(() => item.applyTo(widget.player, target));
      },
    );
  }

  Widget _buildItemTile(MapProp? item) {
    return item != null
        ? GestureDetector(
            onTap: () => _onItemTap(item),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          item.icon,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                      _buildItemTypeIcon(item),
                      _buildItemCountBadge(item),
                    ],
                  ),
                ),
              ],
            ),
          )
        : Container(
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: const Center(),
          );
  }

  Widget _buildItemTypeIcon(MapProp item) {
    final icon = propIcon(item);
    return icon != null
        ? Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Icon(icon),
            ),
          )
        : const Center();
  }

  Widget _buildItemCountBadge(MapProp item) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          '${item.count}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
