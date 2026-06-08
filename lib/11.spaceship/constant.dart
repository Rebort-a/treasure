import 'package:flutter/material.dart';

import '../00.common/l10n/strings.dart';
import 'base.dart';

// ------------------------------ 颜色常量 ------------------------------
class ColorConstants {
  static const Color backgroundColor = Color(0xFF0B1120); // 背景色
  static const Color playerColor = Color(0xFF00F0FF); // 玩家颜色
  static const Color invincibleColor = Color(0xFFADE8F4); // 无敌状态颜色
  static const Color enemyMissile = Colors.yellow; // 导弹
  static const Color enemyFast = Colors.red; // 快速敌人
  static const Color enemyHeavy = Colors.purple; // 重型敌人
  static const Color enemyBoss = Colors.redAccent; // BOSS敌人
  static const Color bulletDefault = Colors.cyan; // 普通子弹

  static const Color textNeonBlue = Color(0xFF00F5FF);
  static const Color textNeonBlueAlpha = Color(0x8000F5FF);
  static const Color textNeonPink = Color(0xFFFF00FF);
  static const Color textYellow = Color(0xFFFFFF00);
  static const Color textGreen = Color(0xFF00FF00);
  static const Color textCyan = Color(0xFF00FFFF);
}

// ------------------------------ 尺寸常量 ------------------------------
class SizeConstants {
  // 玩家相关
  static const Size player = Size(40, 50); // 玩家飞船尺寸

  // 敌人相关
  static const Size enemyMissile = Size(20, 20); // 导弹敌人尺寸
  static const Size enemyFast = Size(30, 30); // 快速敌人尺寸
  static const Size enemyHeavy = Size(40, 40); // 重型敌人尺寸
  static const Size enemyBoss = Size(60, 60); // BOSS敌人尺寸

  // 道具相关
  static const Size prop = Size(25, 25); // 道具通用尺寸

  // 子弹相关
  static const Size bulletNormal = Size(4, 12); // 普通子弹尺寸
  static const Size bulletBig = Size(8, 20); // 大子弹尺寸

  // UI元素
  static const double hudPadding = 16.0; // HUD元素内边距
  static const double buttonSize = 50.0; // 按钮尺寸
}

// ------------------------------ 游戏核心参数 ------------------------------
class ParamConstants {
  // 时间单位：每秒
  static const double enemyMissileSpeed = 250; // 导弹每秒移动像素
  static const double enemyMissileHorizontalSpeed = 100; // 导弹横向速度
  static const double enemyFastSpeed = 150; // 快速敌人每秒移动像素
  static const double enemyHeavySpeed = 100; // 重型敌人每秒移动像素
  static const double enemyBossSpeed = 120; // BOSS移动速度（纵向）
  static const double enemyBossHorizontalSpeed = 80; // BOSS横向基础速度
  static const double bulletSpeed = 500; // 子弹每秒移动像素
  static const double playerSpeed = 20; // 玩家每次移动像素
  static const double propSpeed = 120; // 道具每秒移动像素

  // 玩家属性
  static const int playerInitialHealth = 50; // 初始生命值
  static const double invincibleDurationSeconds = 2; // 无敌状态持续秒数
  static const double playerFlashIntervalSeconds = 0.25; // 无敌闪烁间隔秒数

  // 敌人属性
  static const double enemySpawnInterval = 2; // 敌人生成间隔秒数
  static const int enemyBaseHealth = 5; // 基础/快速敌人初始生命值
  static const int enemyHeavyHealth = 30; // 重型敌人初始生命值
  static const int shieldOffsetDamage = 30; // 护盾碰撞时对敌人的伤害

  // BOSS属性
  static const int bossInitialHealth = 90; // BOSS初始生命值
  static const int bossHealthIncrement = 30; // 每级增加的BOSS生命值
  static const double bossMinionSpawnIntervalSeconds = 2; // BOSS召唤小怪间隔

  // 子弹属性
  static const int bulletBaseDamage = 10; // 基础子弹伤害
  static const double bulletCooldownSeconds = 0.3; // 射击冷却秒数
  static const double bulletTripleMultiplier = 0.5; // 三向子弹伤害倍率
  static const double tripleShotAngle = 15; // 三向子弹射击角度
  static const double bulletBigMultiplier = 1.5; // 大子弹伤害倍率
  static const double bigBulletCooldownSeconds = 0.5; // 大子弹冷却秒数
  static const double bulletFlameMultiplier = 2.0; // 火焰子弹伤害倍率

  // 道具属性
  static const double propEffectDurationSeconds = 10; // 道具效果持续秒数
  static const double propDropRateBasic = 0.25; // 基础敌人道具掉落率
  static const double propDropRateHeavy = 0.5; // 重型敌人道具掉落率
  static const double propDropRateBoss = 1.0; // BOSS道具掉落率

  // 关卡与生成
  static const int enemyCountPerBoss = 10; // 每关需要击杀的敌人数(基础+重型)
  static const int enemyCountPerBossIncrement = 5; // 每级增加的BOSS触发敌人数
  static const double levelUpDelaySeconds = 3; // 等级提升提示持续秒数
  static const double difficultyIncrease = 0.1; // 难度提升系数

  // 星星背景
  static const double minStarSpeed = 1; // 星星最小移动速度（每秒）
  static const double maxStarSpeed = 50; // 星星最大移动速度（每秒）
}

class ProbabilityConstants {
  static const double enemyMissileSpawnRate = 0.3;
  static const double enemyFastSpawnRate = 0.45;
  static const double enemyHeavySpawnRate = 0.25;

  static const double propTripleRate = 0.3;
  static const double propBigRate = 0.3;
  static const double propFlameRate = 0.3;
  static const double propShieldRate = 0.1;
}

// ------------------------------ 文本样式 ------------------------------
class TextStyleConstants {
  // 标题样式（如"星际战机"）
  static const TextStyle title = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.bold,
    color: ColorConstants.textNeonBlue,
    shadows: [
      Shadow(
        color: ColorConstants.textNeonBlueAlpha,
        offset: Offset(0, 0),
        blurRadius: 10,
      ),
      Shadow(color: Colors.black54, offset: Offset(2, 2), blurRadius: 4),
    ],
  );

  // 信息文本样式（生命值、分数、等级）
  static const TextStyle info = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    shadows: [
      Shadow(color: Colors.black54, offset: Offset(2, 2), blurRadius: 4),
    ],
  );

  // 横幅文本样式（如"Boss出现"、"敌人逃脱"）
  static const TextStyle banner = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );
}

// ------------------------------ 时间常量 ------------------------------
class DurationConstants {
  static const Duration achievement = Duration(seconds: 3);
  static const Duration text = Duration(seconds: 2);
  static const Duration alert = Duration(seconds: 3);
}

/// 道具类型扩展方法
extension PropTypeExtension on PropType {
  static IconData getIcon(PropType type) {
    switch (type) {
      case PropType.shield:
        return Icons.shield_outlined;
      case PropType.triple:
        return Icons.exposure_plus_2;
      case PropType.big:
        return Icons.zoom_in;
      case PropType.flame:
        return Icons.whatshot;
    }
  }

  static Color getColor(PropType type) {
    switch (type) {
      case PropType.shield:
        return Colors.green;
      case PropType.big:
        return Colors.amber;
      case PropType.triple:
        return Colors.cyan;
      case PropType.flame:
        return Colors.orange;
    }
  }
}

/// 所有成就列表
class Achievements {
  static List<Achievement> all = [
    Achievement(
      type: AchievementType.firstKill,
      title: S.achFirstKill,
      description: S.achFirstKillDesc,
    ),
    Achievement(
      type: AchievementType.score100,
      title: S.achScore100,
      description: S.achScore100Desc,
    ),
    Achievement(
      type: AchievementType.score500,
      title: S.achScore500,
      description: S.achScore500Desc,
    ),
    Achievement(
      type: AchievementType.score1000,
      title: S.achScore1000,
      description: S.achScore1000Desc,
    ),
    Achievement(
      type: AchievementType.level5,
      title: S.achLevel5,
      description: S.achLevel5Desc,
    ),
    Achievement(
      type: AchievementType.level10,
      title: S.achLevel10,
      description: S.achLevel10Desc,
    ),
    Achievement(
      type: AchievementType.bossKill,
      title: S.achBossHunter,
      description: S.achBossHunterDesc,
    ),
    Achievement(
      type: AchievementType.eightKill,
      title: S.achEightKills,
      description: S.achEightKillsDesc,
    ),
  ];
}
