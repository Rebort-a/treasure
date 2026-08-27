import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../00.common/image/sprite_sheet.dart';
import '../00.common/l10n/strings.dart';
import '../00.common/widget/button/cool_button.dart';
import '../00.common/widget/container/glass_container.dart';
import 'base.dart';
import 'manager.dart';

class TowerDefensePage extends StatefulWidget {
  const TowerDefensePage({super.key});

  @override
  State<TowerDefensePage> createState() => _TowerDefensePageState();
}

class _TowerDefensePageState extends State<TowerDefensePage> {
  late final Manager _manager;
  bool _mapInitialized = false;
  final Map<EnemyType, SpriteSheet> _sheets = {};
  SpriteSheet? _slashSheet;

  @override
  void initState() {
    super.initState();
    _manager = Manager(); // Manager 自持 Ticker，构造即启动游戏循环
    _loadSprites();
  }

  /// 预加载四种怪物 + 击杀特效 spritesheet（加载完成前绘制回退色圆）
  Future<void> _loadSprites() async {
    final entries = await Future.wait(
      EnemySprites.all.entries.map(
        (e) => SpriteSheet.load(
          e.value.asset,
          e.value.columns,
          e.value.rows,
        ).then((sheet) => MapEntry(e.key, sheet)),
      ),
    );
    final slash = await SpriteSheet.load(
      SlashSprites.asset,
      SlashSprites.columns,
      SlashSprites.rows,
    );
    if (!mounted) return;
    setState(() {
      _sheets.addEntries(entries);
      _slashSheet = slash;
    });
  }

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.towerDefense),
        centerTitle: true,
        actions: [_buildActions()],
      ),
      body: Column(
        children: [
          _buildHud(),
          Expanded(child: RepaintBoundary(child: _buildGameArea())),
        ],
      ),
    );
  }

  // ==================== HUD ====================

  Widget _buildHud() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: Colors.black87,
      child: Row(
        children: [
          Expanded(
            child: _hudItem(Icons.monetization_on, Colors.amber, _manager.gold),
          ),
          Expanded(child: _hudItem(Icons.favorite, Colors.red, _manager.lives)),
          Expanded(
            child: _hudItem(
              Icons.waves,
              Colors.cyan,
              _manager.waveNumber,
              prefix: S.wavePrefix,
            ),
          ),
          Expanded(
            child: _hudItem(Icons.whatshot, Colors.orange, _manager.kills),
          ),
          Expanded(
            child: _hudItem(
              Icons.directions_run,
              Colors.grey,
              _manager.escaped,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hudItem(
    IconData icon,
    Color color,
    ValueListenable<int> listenable, {
    String prefix = '',
  }) {
    return ValueListenableBuilder<int>(
      valueListenable: listenable,
      builder: (_, value, __) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            '$prefix$value',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ==================== AppBar 操作：倍速 / 暂停 / 重开 ====================

  Widget _buildActions() {
    return ValueListenableBuilder<GameState>(
      valueListenable: _manager.state,
      builder: (_, state, __) {
        final inGame = state == GameState.playing || state == GameState.paused;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<double>(
              valueListenable: _manager.speed,
              builder: (context, speed, __) => IconButton(
                icon: Text(
                  '${speed.toInt()}x',
                  style: TextStyle(
                    // 1x 时与相邻 AppBar 图标按钮同源取色（onSurface），>1x 高亮琥珀
                    color: speed > 1
                        ? Colors.amber
                        : IconTheme.of(context).color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _manager.cycleSpeed,
              ),
            ),
            IconButton(
              icon: Icon(
                state == GameState.paused ? Icons.play_arrow : Icons.pause,
              ),
              onPressed: inGame ? _manager.togglePause : null,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _restart,
            ),
          ],
        );
      },
    );
  }

  // ==================== 战场区 ====================

  Widget _buildGameArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const cellSize = Manager.cellSize;
        final availW = constraints.maxWidth;
        final availH = constraints.maxHeight;
        final w = (availW / cellSize).floor().clamp(1, 60);
        final h = ((availH - 56) / cellSize).floor().clamp(1, 60); // 预留底部面板区
        if (!_mapInitialized) {
          _mapInitialized = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _manager.initGame(width: w, height: h));
            }
          });
          return const SizedBox.shrink();
        }
        final mapW = _manager.map.width * cellSize;
        final mapH = _manager.map.height * cellSize;
        return Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: GestureDetector(
                onTapUp: (details) => _handleTap(details),
                child: CustomPaint(
                  size: Size(mapW, mapH),
                  painter: _GamePainter(_manager, _sheets, _slashSheet),
                ),
              ),
            ),
            ValueListenableBuilder<GameState>(
              valueListenable: _manager.state,
              builder: (_, state, __) {
                if (state == GameState.preparing) return _buildStartFloat();
                if (state == GameState.won || state == GameState.lost) {
                  return _buildResultFloat(state == GameState.won);
                }
                return const SizedBox.shrink();
              },
            ),
            Positioned(left: 0, right: 0, bottom: 0, child: _buildBuildPanel()),
          ],
        );
      },
    );
  }

  Widget _buildStartFloat() {
    return Positioned.fill(
      child: Center(
        child: GlassContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                S.towerDefense,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '${S.startWave} #${_manager.waveNumber.value + 1}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              CoolButton(
                text: S.startGame,
                icon: Icons.play_arrow,
                onTap: _manager.startNextWave,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultFloat(bool won) {
    return Positioned.fill(
      child: Center(
        child: GlassContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                won ? S.victory : S.defeat,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: won ? Colors.amber : Colors.red,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _restart,
                child: Text(S.startNewGame),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _restart() {
    setState(
      () => _manager.initGame(
        width: _manager.map.width,
        height: _manager.map.height,
      ),
    );
  }

  // ==================== 点击交互 ====================

  void _handleTap(TapUpDetails details) {
    final cellSize = Manager.cellSize;
    final x = (details.localPosition.dx / cellSize).floor();
    final y = (details.localPosition.dy / cellSize).floor();
    if (!_manager.map.inBounds(x, y)) return;

    final cell = _manager.map.cells[y][x];
    if (cell.isTower) {
      _manager.selectFort(GridPos(x, y));
    } else {
      _manager.selectFort(null);
    }
    _manager.selectCellType(null);
  }

  // ==================== 底部面板（建塔/升级统一） ====================

  /// 确认/取消按钮统一样式（默认风格胶囊）与垂直间距
  static final ButtonStyle _panelBtnStyle = ElevatedButton.styleFrom(
    visualDensity: VisualDensity.compact,
    minimumSize: Size.zero,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  );
  static const double _panelBtnGap = 6.0;

  /// 监听 manager（而非仅 selectedFort）：游戏中塔血量、金币每帧变化，
  /// 选中塔的底板需随之刷新（selectFort/selectCellType/upgrade 亦经 manager 通知）
  Widget _buildBuildPanel() {
    return ListenableBuilder(
      listenable: _manager,
      builder: (context, _) {
        final fort = _manager.selectedFort.value;
        if (fort == null) return const SizedBox.shrink();
        Tower? tower;
        for (final t in _manager.towers.value) {
          if (t.pos.x == fort.x && t.pos.y == fort.y) {
            tower = t;
            break;
          }
        }
        if (tower == null) return const SizedBox.shrink();
        return _buildTowerPanel(tower);
      },
    );
  }

  /// 统一塔面板：[当前道具卡(重建)] [进化卡片] [✓/✗]
  ///
  /// 外层 _buildBuildPanel 已监听 manager（游戏中每帧 notifyListeners），
  /// selected / curHp / gold 直接读取即为最新，无需再套 selectedTower 监听。
  Widget _buildTowerPanel(Tower fort) {
    final curType = fort.type;
    final curCfg = TowerConfigs.getConfig(curType);
    final curHp = fort.hp;
    final curMax = fort.maxHp;
    final selected = _manager.selectedTower.value;
    final isRebuild = selected == curType;
    final confirmEnabled = selected != null &&
        _manager.gold.value >= TowerConfigs.getConfig(selected).cost &&
        (!isRebuild || curHp < curMax);
    return _buildBottomPanel(
      currentCard: _buildTowerCard(
        curType,
        hpText: S.hp(curHp, curMax),
        cost: curCfg.cost,
        isSelected: isRebuild,
        isRebuildCard: true,
        onTap: () => _manager.selectCellType(isRebuild ? null : curType),
      ),
      evolveCards: curCfg.upgrades.map((toType) {
        final cfg = TowerConfigs.getConfig(toType);
        return _buildTowerCard(
          toType,
          hpText: S.hpMax(cfg.maxHp),
          cost: cfg.cost,
          isSelected: selected == toType,
          onTap: () => _manager.selectCellType(
            selected == toType ? null : toType,
          ),
        );
      }).toList(),
      confirmEnabled: confirmEnabled,
      onConfirm: () {
        final ok = _manager.upgradeTower(
          fort,
          isRebuild ? fort.type : selected!,
        );
        if (ok) _manager.selectFort(null);
        _manager.selectCellType(null);
      },
      onCancel: () {
        _manager.selectFort(null);
        _manager.selectCellType(null);
      },
    );
  }

  /// 统一底部面板：从左往右 1.当前道具卡(重建) 2.进化卡片 3.确认(上)/取消(下)
  Widget _buildBottomPanel({
    required Widget currentCard,
    required List<Widget> evolveCards,
    required bool confirmEnabled,
    required VoidCallback onConfirm,
    required VoidCallback onCancel,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          currentCard,
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: evolveCards,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                style: _panelBtnStyle,
                onPressed: confirmEnabled ? onConfirm : null,
                child: Icon(
                  Icons.check,
                  color: confirmEnabled ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(height: _panelBtnGap),
              ElevatedButton(
                style: _panelBtnStyle,
                onPressed: onCancel,
                child: const Icon(Icons.close, color: Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 道具卡片：图标 + 名称 + 血量 + 价格；重建卡以 Icons.refresh 代替 emoji
  Widget _buildTowerCard(
    CellType type, {
    required String hpText,
    required int cost,
    required bool isSelected,
    required VoidCallback onTap,
    bool isRebuildCard = false,
  }) {
    final config = TowerConfigs.getConfig(type);
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          // 金边外扩：恒定露出宽度避免跳变，透明=视觉无边，选中=外层金边
          color: isSelected ? const Color(0xFFFFD700) : Colors.transparent,
          borderRadius: BorderRadius.circular(11), // 内层 8 + 露边 3
        ),
        child: Container(
          margin: const EdgeInsets.all(3), // 露出外层 3px 作选中金边
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: kFieldColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              isRebuildCard
                  ? const Icon(Icons.refresh, size: 20, color: Colors.white)
                  : Text(towerEmoji(type), style: const TextStyle(fontSize: 20)),
              Text(
                config.name,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              Text(
                hpText,
                style: const TextStyle(color: Colors.white70, fontSize: 9),
              ),
              Text(
                S.goldCost(cost),
                style: const TextStyle(color: Colors.amber, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== 怪物精灵配置 ====================

class EnemySpriteDef {
  final String asset;
  final int columns;
  final int rows;
  final int walkRow; // 行走动画所在行
  final int walkFrames; // 行走帧数
  final double fps;
  final bool flipX; // 精灵默认朝左时需水平翻转（敌人向右行进）
  final double displayScale; // 显示高度 = cellSize * displayScale

  const EnemySpriteDef({
    required this.asset,
    required this.columns,
    required this.rows,
    required this.walkRow,
    required this.walkFrames,
    required this.fps,
    required this.flipX,
    required this.displayScale,
  });
}

class EnemySprites {
  static const String slimeAsset = 'assets/images/slime.png';
  static const String goblinAsset = 'assets/images/goblin.png';
  static const String trollAsset = 'assets/images/troll.png';
  static const String cyclopsAsset = 'assets/images/cyclops.png';

  static const Map<EnemyType, EnemySpriteDef> all = {
    EnemyType.slime: EnemySpriteDef(
      asset: slimeAsset,
      columns: 10,
      rows: 4,
      walkRow: 0,
      walkFrames: 8,
      fps: 8,
      flipX: false,
      displayScale: 0.7,
    ),
    EnemyType.goblin: EnemySpriteDef(
      asset: goblinAsset,
      columns: 14,
      rows: 6,
      walkRow: 1,
      walkFrames: 8,
      fps: 8,
      flipX: false,
      displayScale: 0.8,
    ),
    EnemyType.troll: EnemySpriteDef(
      asset: trollAsset,
      columns: 4,
      rows: 4,
      walkRow: 1,
      walkFrames: 4,
      fps: 4,
      flipX: true,
      displayScale: 0.75,
    ),
    EnemyType.cyclops: EnemySpriteDef(
      asset: cyclopsAsset,
      columns: 20,
      rows: 6,
      walkRow: 1,
      walkFrames: 4,
      fps: 4,
      flipX: false,
      displayScale: 0.9,
    ),
  };

  static EnemySpriteDef get(EnemyType type) => all[type]!;
}

/// 击杀飞溅特效配置（slash_blood_spritesheet.png 256×64，4 帧 64×64）
class SlashSprites {
  static const String asset = 'assets/images/slash_blood_spritesheet.png';
  static const int columns = 4;
  static const int rows = 1;
  static const int frames = 4;
  static const double fps = 12;
  static const double displayScale = 1.2;
}

// ==================== 游戏画面绘制 ====================

class _GamePainter extends CustomPainter {
  final Manager manager;
  final Map<EnemyType, SpriteSheet> sheets;
  final SpriteSheet? slashSheet;

  _GamePainter(this.manager, this.sheets, this.slashSheet)
    : super(repaint: manager);

  static const Color _enterColor = Color(0xFF66BB6A); // 入口绿
  static const Color _exitColor = Color(0xFFEF5350); // 出口红
  static const Color _rangeColor = Color(0xFF81D4FA); // 攻击范围浅蓝

  /// 图标缓存（全图大量绘制，静态缓存避免每帧重复 layout）
  static final Map<String, TextPainter> _textPainters = {};
  static TextPainter _emojiPainter(String emoji) =>
      _textPainters[emoji] ??= TextPainter(
        text: TextSpan(text: emoji, style: const TextStyle(fontSize: 20)),
        textDirection: TextDirection.ltr,
      )..layout();

  static final Map<int, TextPainter> _iconPainters = {};
  static TextPainter _iconPainter(IconData icon, Color color) {
    final key = icon.codePoint * 17 + color.toARGB32();
    return _iconPainters[key] ??= TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          color: color,
          fontSize: 18,
          fontFamily: icon.fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = Manager.cellSize;
    final map = manager.map;

    // 网格：统一底色 + enter/exit 图标 + 网格线
    for (int y = 0; y < map.height; y++) {
      for (int x = 0; x < map.width; x++) {
        final rect = Rect.fromLTWH(
          x * cellSize,
          y * cellSize,
          cellSize,
          cellSize,
        );
        canvas.drawRect(rect, Paint()..color = kFieldColor);
        final cell = map.cells[y][x];
        if (cell == CellType.enter || cell == CellType.exit) {
          final isEnter = cell == CellType.enter;
          final tp = _iconPainter(
            isEnter ? Icons.door_sliding : Icons.exit_to_app,
            isEnter ? _enterColor : _exitColor,
          );
          tp.paint(
            canvas,
            Offset(
              rect.center.dx - tp.width / 2,
              rect.center.dy - tp.height / 2,
            ),
          );
        }
        canvas.drawRect(
          rect,
          Paint()
            ..color = Colors.black26
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5,
        );
      }
    }

    final selFort = manager.selectedFort.value;
    final selType = manager.selectedTower.value;

    // 选中塔的攻击范围（预览目标形态优先）
    if (selFort != null) {
      final tower = _towerAt(selFort);
      final showType =
          (selType != null && tower != null && selType != tower.type)
          ? selType
          : tower?.type;
      if (showType != null) {
        final cfg = TowerConfigs.getConfig(showType);
        if (cfg.fireRate > 0) {
          _drawRange(canvas, selFort, showType, cellSize);
        }
      }
    }

    // 塔：选中格画阴影底；进化预览格走半透明预览态，其余正常绘制
    for (final tower in manager.towers.value) {
      final isSelected = selFort != null &&
          tower.pos.x == selFort.x &&
          tower.pos.y == selFort.y;
      final isEvolvePreview =
          isSelected && selType != null && selType != tower.type;
      if (isEvolvePreview) {
        _drawPreviewTower(canvas, tower.pos, selType, cellSize);
      } else if (isSelected) {
        _drawShadowRect(canvas, tower.pos, cellSize);
        _drawTower(canvas, tower, cellSize);
      } else {
        _drawTower(canvas, tower, cellSize);
      }
    }

    // 敌人（spritesheet 行走动画，未加载完前回退色圆）
    for (final enemy in manager.enemies.value) {
      if (!enemy.alive) continue;
      _drawEnemy(canvas, enemy, cellSize);
    }

    // 飞弹
    _drawProjectiles(canvas);

    // 击杀飞溅特效
    _drawEffects(canvas, cellSize);
  }

  Tower? _towerAt(GridPos pos) {
    for (final t in manager.towers.value) {
      if (t.pos.x == pos.x && t.pos.y == pos.y) return t;
    }
    return null;
  }

  void _drawRange(Canvas canvas, GridPos pos, CellType type, double cellSize) {
    final center = Offset(
      (pos.x + 0.5) * cellSize,
      (pos.y + 0.5) * cellSize,
    );
    final radius = TowerConfigs.getConfig(type).range * cellSize;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = _rangeColor.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = _rangeColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  /// 正常塔：仅图标 + 受损血条（不画背景色块，靠 emoji 区分形态）
  void _drawTower(Canvas canvas, Tower tower, double cellSize) {
    final rect = Rect.fromLTWH(
      tower.pos.x * cellSize,
      tower.pos.y * cellSize,
      cellSize,
      cellSize,
    );
    final tp = _emojiPainter(towerEmoji(tower.type));
    tp.paint(
      canvas,
      Offset(rect.center.dx - tp.width / 2, rect.center.dy - tp.height / 2),
    );
    _drawHpBar(
      canvas,
      Rect.fromLTWH(rect.left, rect.bottom - 3, rect.width, 3),
      tower.hp / tower.maxHp,
    );
  }

  /// 选中塔的阴影底：缩小圆角矩形，放置预览与纯选中态共用；返回阴影矩形供叠加用
  Rect _drawShadowRect(Canvas canvas, GridPos pos, double cellSize) {
    final rect = Rect.fromLTWH(
      pos.x * cellSize + 3,
      pos.y * cellSize + 3,
      cellSize - 6,
      cellSize - 6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );
    return rect;
  }

  /// 预览态：阴影底 + 半透明 emoji（模拟放置阴影/占位）
  void _drawPreviewTower(
    Canvas canvas,
    GridPos pos,
    CellType type,
    double cellSize,
  ) {
    final rect = _drawShadowRect(canvas, pos, cellSize);
    // emoji 半透明：用 saveLayer 全局不透明度叠加（emoji 为彩色字形，无法靠 color 控制）
    final tp = _emojiPainter(towerEmoji(type));
    canvas.saveLayer(rect, Paint()..color = const Color(0x80FFFFFF));
    tp.paint(
      canvas,
      Offset(rect.center.dx - tp.width / 2, rect.center.dy - tp.height / 2),
    );
    canvas.restore();
  }

  void _drawEnemy(Canvas canvas, Enemy enemy, double cellSize) {
    final pos = manager.getEnemyPixelPos(enemy);
    final def = EnemySprites.get(enemy.type);
    final sheet = sheets[enemy.type];

    double halfW;
    double topY;
    if (sheet == null) {
      final radius = enemy.type == EnemyType.cyclops ? 10.0 : 7.0;
      canvas.drawCircle(
        pos,
        radius,
        Paint()..color = EnemyColors.get(enemy.type),
      );
      halfW = radius;
      topY = pos.dy - radius;
    } else {
      // 行走帧：按动画时钟循环，hashCode 相位错开同屏怪物
      final frame =
          ((manager.animTime * def.fps +
                    (enemy.hashCode % 100) / 100 * def.walkFrames) %
                def.walkFrames)
              .floor();
      final src = sheet.frameRect(def.walkRow * sheet.columns + frame);
      final drawH = cellSize * def.displayScale;
      final drawW = drawH * sheet.cellWidth / sheet.cellHeight;
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      if (def.flipX) canvas.scale(-1, 1);
      canvas.drawImageRect(
        sheet.image,
        src,
        Rect.fromLTWH(-drawW / 2, -drawH / 2, drawW, drawH),
        Paint(),
      );
      canvas.restore();
      halfW = drawW / 2;
      topY = pos.dy - drawH / 2;
    }

    _drawHpBar(
      canvas,
      Rect.fromLTWH(pos.dx - halfW, topY - 5, halfW * 2, 3),
      enemy.hp / enemy.config.maxHp,
    );
  }

  void _drawProjectiles(Canvas canvas) {
    final paint = Paint()..color = const Color(0xFFFFEB3B);
    for (final p in manager.projectiles.value) {
      canvas.drawCircle(manager.getProjectilePos(p), 3, paint);
    }
  }

  void _drawEffects(Canvas canvas, double cellSize) {
    final sheet = slashSheet;
    if (sheet == null) return;
    for (final e in manager.effects.value) {
      final frame = ((manager.animTime - e.bornAt) * SlashSprites.fps).floor();
      if (frame < 0 || frame >= SlashSprites.frames) continue;
      final src = sheet.frameRect(frame);
      final drawH = cellSize * SlashSprites.displayScale;
      final drawW = drawH * sheet.cellWidth / sheet.cellHeight;
      canvas.drawImageRect(
        sheet.image,
        src,
        Rect.fromLTWH(e.pos.dx - drawW / 2, e.pos.dy - drawH / 2, drawW, drawH),
        Paint(),
      );
    }
  }

  void _drawHpBar(Canvas canvas, Rect bar, double ratio) {
    final r = ratio.clamp(0.0, 1.0);
    if (r >= 1.0) return;
    canvas.drawRect(bar, Paint()..color = Colors.black54);
    canvas.drawRect(
      Rect.fromLTWH(bar.left, bar.top, bar.width * r, bar.height),
      Paint()
        ..color = r > 0.5
            ? Colors.green
            : (r > 0.25 ? Colors.orange : Colors.red),
    );
  }

  @override
  bool shouldRepaint(covariant _GamePainter oldDelegate) =>
      !identical(sheets, oldDelegate.sheets) ||
      !identical(slashSheet, oldDelegate.slashSheet);
}
