import 'package:flutter/material.dart';

import '../../00.common/widget/banner/banner_template.dart';
import '../../l10n/strings.dart';
import '../middle/prop.dart';
import '../middle/player.dart';

class StorePage extends StatefulWidget {
  final NormalPlayer player;
  const StorePage({super.key, required this.player});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
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
        title: Text(S.store),
        centerTitle: true,
        backgroundColor: Colors.green[100],
      ),
      backgroundColor: Colors.green[800],
      body: Column(
        children: [
          _buildGoldDisplay(),
          _buildStoreGrid(),
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
        color: Colors.green[100],
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Text(S.coinCount(widget.player.money))],
      ),
    );
  }

  Widget _buildStoreGrid() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(8.0),
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.green[100],
          border: Border.all(color: Colors.black, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          padding: const EdgeInsets.all(10),
          children: PropCollection.totalItems.values.map((item) {
            return _buildItemTile(item);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildItemTile(MapProp item) {
    return GestureDetector(
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
                  child: Text(item.icon, style: const TextStyle(fontSize: 24)),
                ),
                _buildItemTypeIcon(item),
                _buildItemPriceBadge(item),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTypeIcon(MapProp item) {
    return item.type != null
        ? Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Icon(item.type),
            ),
          )
        : const Center();
  }

  Widget _buildItemPriceBadge(MapProp item) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          '\$${item.price}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildSelectedItemInfo() {
    return Visibility(
      visible: _selectedItem.name != '',
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
            ElevatedButton(onPressed: _buyItem, child: Text(S.buy)),
          ],
        ),
      ),
    );
  }

  void _buyItem() {
    if (widget.player.money >= _selectedItem.price) {
      widget.player.money -= _selectedItem.price;
      setState(() {
        widget.player.props[_selectedItem.id]?.count += 1;
      });
      BannerTemplate.snackBarDialog(context, S.buySuccess);
    } else {
      BannerTemplate.snackBarDialog(context, S.notEnoughCoins);
    }
  }
}
