import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../00.common/game/map.dart';
import '../../00.common/image/entity.dart';
import '../base/effect.dart';
import '../base/energy.dart';
import '../base/skill.dart';

mixin EnergyConfigMixin {
  bool aptitude = true;
  int healthPoints = 0;
  int attackPoints = 0;
  int defencePoints = 0;
  int skillPoints = 0;

  int get level => healthPoints + attackPoints + defencePoints + skillPoints;
}

class EnergyConfig with EnergyConfigMixin {
  EnergyConfig({
    bool? aptitude,
    int? healthPoints,
    int? attackPoints,
    int? defencePoints,
    int? skillPoints,
  }) {
    this.aptitude = aptitude ?? true;
    this.healthPoints = healthPoints ?? 0;
    this.attackPoints = attackPoints ?? 0;
    this.defencePoints = defencePoints ?? 0;
    this.skillPoints = skillPoints ?? 1;
  }

  String toStringFormat() {
    return '[${aptitude ? '1' : '0'},$healthPoints,$attackPoints,$defencePoints,$skillPoints]';
  }

  static EnergyConfig fromStringFormat(String str) {
    // 移除方括号并分割字符串
    final parts = str.substring(1, str.length - 1).split(',');
    if (parts.length != 5) {
      throw FormatException('Invalid config string format: $str');
    }

    return EnergyConfig(
      aptitude: parts[0] == '1',
      healthPoints: int.parse(parts[1]),
      attackPoints: int.parse(parts[2]),
      defencePoints: int.parse(parts[3]),
      skillPoints: int.parse(parts[4]),
    );
  }
}

class EnergyConfigs {
  late final List<EnergyConfig> _configs;

  EnergyConfigs({
    required EnergyConfig metal,
    required EnergyConfig wood,
    required EnergyConfig water,
    required EnergyConfig fire,
    required EnergyConfig earth,
  }) {
    _configs = [metal, wood, water, fire, earth];
  }

  EnergyConfig operator [](EnergyType sign) => _configs[sign.index];

  Iterable<EnergyConfig> get values => List.unmodifiable(_configs);

  factory EnergyConfigs.defaultConfigs({
    bool? aptitude = true,
    int? healthPoints = 0,
    int? attackPoints = 0,
    int? defencePoints = 0,
    int? skillPoints = 0,
  }) {
    EnergyConfig createConfig() => EnergyConfig(
      aptitude: aptitude,
      healthPoints: healthPoints,
      attackPoints: attackPoints,
      defencePoints: defencePoints,
      skillPoints: skillPoints,
    );

    return EnergyConfigs(
      metal: createConfig(),
      wood: createConfig(),
      water: createConfig(),
      fire: createConfig(),
      earth: createConfig(),
    );
  }

  factory EnergyConfigs.fromManagers(EnergyManagers managers) {
    final configs = EnergyType.values.map((sign) {
      final manager = managers[sign];
      return EnergyConfig(
        aptitude: manager.aptitude,
        healthPoints: manager.healthPoints,
        attackPoints: manager.attackPoints,
        defencePoints: manager.defencePoints,
        skillPoints: manager.skillPoints,
      );
    }).toList();

    return EnergyConfigs(
      metal: configs[EnergyType.metal.index],
      wood: configs[EnergyType.wood.index],
      water: configs[EnergyType.water.index],
      fire: configs[EnergyType.fire.index],
      earth: configs[EnergyType.earth.index],
    );
  }

  String configToString() {
    final metal = _configs[EnergyType.metal.index].toStringFormat();
    final wood = _configs[EnergyType.wood.index].toStringFormat();
    final water = _configs[EnergyType.water.index].toStringFormat();
    final fire = _configs[EnergyType.fire.index].toStringFormat();
    final earth = _configs[EnergyType.earth.index].toStringFormat();

    return '{$metal,$wood,$water,$fire,$earth}';
  }

  factory EnergyConfigs.fromString(String str) {
    // 移除大括号并分割配置字符串
    final configStr = str.substring(1, str.length - 1);
    final configs = _parseConfigList(configStr);

    if (configs.length != EnergyType.values.length) {
      throw FormatException('Invalid configs string format: $str');
    }

    return EnergyConfigs(
      metal: configs[EnergyType.metal.index],
      wood: configs[EnergyType.wood.index],
      water: configs[EnergyType.water.index],
      fire: configs[EnergyType.fire.index],
      earth: configs[EnergyType.earth.index],
    );
  }

  // 辅助方法：解析配置列表字符串
  static List<EnergyConfig> _parseConfigList(String str) {
    final configs = <EnergyConfig>[];
    int startIndex = 0;
    int bracketCount = 0;

    for (int i = 0; i < str.length; i++) {
      if (str[i] == '[') {
        bracketCount++;
      } else if (str[i] == ']') {
        bracketCount--;
        if (bracketCount == 0) {
          final configStr = str.substring(startIndex, i + 1);
          configs.add(EnergyConfig.fromStringFormat(configStr));
          startIndex = i + 2; // 跳过逗号和空格
        }
      }
    }

    return configs;
  }
}

class EnergyManager extends Energy with EnergyConfigMixin {
  EnergyManager({required super.type, required String baseName})
    : super(name: '$baseName.${type.text}}');

  @override
  set healthPoints(int value) => _updateAttribute(AttributeType.hp, value);

  @override
  set attackPoints(int value) => _updateAttribute(AttributeType.atk, value);

  @override
  set defencePoints(int value) => _updateAttribute(AttributeType.def, value);

  @override
  set skillPoints(int value) {
    if (value > skillPoints) {
      for (int i = skillPoints; i < value; i++) {
        learnSkill(i);
      }
    }
    super.skillPoints = value;
  }

  void _updateAttribute(AttributeType sign, int value) {
    final diff = value - _getCurrentValue(sign);
    if (diff > 0) {
      for (int i = 0; i < diff; i++) {
        upgradeAttributes(sign);
      }
    }
  }

  int _getCurrentValue(AttributeType sign) {
    return switch (sign) {
      AttributeType.hp => healthPoints,
      AttributeType.atk => attackPoints,
      AttributeType.def => defencePoints,
    };
  }
}

class EnergyManagers {
  late final List<EnergyManager> _managers;

  EnergyManagers({
    required EnergyManager metal,
    required EnergyManager wood,
    required EnergyManager water,
    required EnergyManager fire,
    required EnergyManager earth,
  }) {
    _managers = [metal, wood, water, fire, earth];
  }

  EnergyManager operator [](EnergyType sign) => _managers[sign.index];

  Iterable<EnergyManager> get values => List.unmodifiable(_managers);

  static EnergyManagers fromConfigs(String baseName, EnergyConfigs configs) {
    final managers = EnergyType.values.map((sign) {
      final config = configs[sign];
      return EnergyManager(type: sign, baseName: baseName)
        ..aptitude = config.aptitude
        ..healthPoints = config.healthPoints
        ..attackPoints = config.attackPoints
        ..defencePoints = config.defencePoints
        ..skillPoints = config.skillPoints;
    }).toList();

    return EnergyManagers(
      metal: managers[EnergyType.metal.index],
      wood: managers[EnergyType.wood.index],
      water: managers[EnergyType.water.index],
      fire: managers[EnergyType.fire.index],
      earth: managers[EnergyType.earth.index],
    );
  }
}

class EnergyResume {
  final EnergyType type;
  final int health;

  const EnergyResume({required this.type, required this.health});
}

class ElementalPreview {
  final ValueNotifier<String> name = ValueNotifier("");
  final ValueNotifier<EnergyType> type = ValueNotifier(EnergyType.metal);
  final ValueNotifier<String> typeString = ValueNotifier(EnergyType.metal.text);
  final ValueNotifier<int> level = ValueNotifier(0);
  final ValueNotifier<int> health = ValueNotifier(0);
  final ValueNotifier<int> capacity = ValueNotifier(0);
  final ValueNotifier<int> attack = ValueNotifier(0);
  final ValueNotifier<int> defence = ValueNotifier(0);
  final ValueNotifier<List<EnergyResume>> resumes = ValueNotifier([]);
  final ValueNotifier<double> emoji = ValueNotifier(0);

  EnergyType updatePreview(EnergyManagers strategy, EnergyType current) {
    _updateResumesInfo(strategy, current);
    _updateCurrentInfo(strategy, resumes.value.first.type);
    return resumes.value.first.type;
  }

  void _updateResumesInfo(EnergyManagers strategy, EnergyType current) {
    _updateResumes(strategy, current);
    _updateEmoji();
  }

  void _updateResumes(EnergyManagers strategy, EnergyType current) {
    List<EnergyResume> temp = [];
    EnergyType start = current;
    for (int i = 0; i < EnergyType.values.length; i++) {
      EnergyManager manager = strategy[start];

      if (manager.aptitude) {
        temp.add(EnergyResume(type: start, health: strategy[start].health));
      }
      start = start.getGenerativeType();
    }
    resumes.value = temp;
  }

  void _updateEmoji() {
    final survivalCount = resumes.value.where((r) => r.health > 0).length;
    final healthValue = health.value;
    final capacityValue = capacity.value;
    emoji.value = (capacityValue > 0 && resumes.value.isNotEmpty)
        ? (survivalCount / resumes.value.length) * (healthValue / capacityValue)
        : 0;
  }

  void _updateCurrentInfo(EnergyManagers strategy, EnergyType current) {
    EnergyManager energy = strategy[current];
    name.value = energy.name;
    type.value = energy.type;
    typeString.value = energy.type.text;
    level.value = energy.level;
    health.value = energy.health;
    capacity.value = energy.capacityTotal;
    attack.value = energy.attackTotal;
    defence.value = energy.defenceTotal;
  }

  void updatePredictedInfo(int attackValue, int defenceValue) {
    attack.value = attackValue;
    defence.value = defenceValue;
  }
}

class Elemental {
  final ElementalPreview preview = ElementalPreview();
  late final EnergyManagers _core;

  late String _baseName;
  late EnergyType _current;

  Elemental({
    required String baseName,
    required EnergyConfigs configs,
    required int current,
  }) {
    _initElemental(baseName, configs, current);
  }

  void _initElemental(String baseName, EnergyConfigs configs, int current) {
    _baseName = baseName;
    _core = EnergyManagers.fromConfigs(baseName, configs);
    _current = preview.updatePreview(_core, EnergyType.values[current]);
  }

  void switchPrevious() => switchAppoint(findPreviousAvailable(_current));
  void switchNext() => switchAppoint(findNextAvailable(_current));
  void switchNextAlive() => switchAppoint(findNextAlive(_current));

  void switchAppoint(EnergyType sign) {
    if (sign != _current) {
      _current = sign;
      _updatePreview();
    }
  }

  EnergyType findPreviousAvailable(EnergyType start) {
    return findAvailable(start, -1, false);
  }

  EnergyType findNextAvailable(EnergyType start) {
    return findAvailable(start, 1, false);
  }

  EnergyType findNextAlive(EnergyType start) {
    return findAvailable(start, 1, true);
  }

  EnergyType findAvailable(EnergyType start, int direction, bool requireAlive) {
    int count = EnergyType.values.length;
    for (int i = 1; i < count; i++) {
      int index = (start.index + direction * i + count) % count;
      EnergyManager energy = _core[EnergyType.values[index]];
      if (energy.aptitude && (!requireAlive || energy.health > 0)) {
        return energy.type;
      }
    }
    return start;
  }

  // 根据五行相生顺序切换到下一个有效灵根
  bool switchAliveByOrder() {
    if (preview.resumes.value.length > 1) {
      EnergyResume resume = preview.resumes.value[1];
      if (resume.health > 0) {
        switchAppoint(resume.type);
        return true;
      }
    }
    return false;
  }

  String get baseName => _baseName;
  EnergyType get current => _current;
  String getAppointName(EnergyType sign) => _core[sign].name;
  bool getAppointAptitude(EnergyType sign) => _core[sign].aptitude;
  int getAppointLevel(EnergyType sign) => _core[sign].level;
  int getAppointCapacity(EnergyType sign) => _core[sign].capacityBase;
  int getAppointAttackBase(EnergyType sign) => _core[sign].attackBase;
  int getAppointDefenceBase(EnergyType sign) => _core[sign].defenceBase;
  int getAppointHealth(EnergyType sign) => _core[sign].health;
  int getAppointAttack(EnergyType sign) => _core[sign].attackTotal;
  int getAppointDefence(EnergyType sign) => _core[sign].defenceTotal;
  String getAppointTypeString(EnergyType sign) => sign.text;

  List<CombatSkill> getAppointSkills(EnergyType sign) => _core[sign].skills;
  List<CombatEffect> getAppointEffects(EnergyType sign) => _core[sign].effects;

  void updateAllNames(String newName) {
    _baseName = newName;
    for (EnergyType sign in EnergyType.values) {
      _core[sign].changeName('$_baseName.${sign.text}');
    }
    _updatePreview();
  }

  void restoreAllAttributesAndEffects() {
    for (Energy e in _core.values) {
      e.restoreAttributes();
      e.restoreEffects();
    }
    _updatePreview();
  }

  void upgradeAppointAttribute(EnergyType sign, AttributeType attribute) {
    switch (attribute) {
      case AttributeType.hp:
        _core[sign].healthPoints++;
      case AttributeType.atk:
        _core[sign].attackPoints++;
      case AttributeType.def:
        _core[sign].defencePoints++;
    }
    _updatePreview();
  }

  void upgradeAppointSkill(EnergyType sign) => _core[sign].skillPoints++;

  void recoverAppoint(EnergyType sign, int value) {
    _core[sign].recoverHealth(value);
    _updatePreview();
  }

  void applyAllPassiveEffect() {
    for (Energy e in _core.values) {
      e.applyPassiveEffect();
    }
    _updatePreview();
  }

  void appointSufferSkill(EnergyType sign, CombatSkill skill) {
    _core[sign].sufferSkill(skill);
    _updatePreview();
  }

  int confrontReply(int Function(EnergyManager) handler) =>
      handler(_core[_current]);

  void confrontRequest(Elemental elemental) {
    final attackValue = elemental.confrontReply(
      (e) => EnergyCombat.handleAttackEffect(_core[_current], e, false),
    );

    final defenceValue = elemental.confrontReply(
      (e) => EnergyCombat.handleDefenceEffect(e, _core[_current], false),
    );

    preview.updatePredictedInfo(attackValue, defenceValue);
  }

  EnergyCombat comabtReply(
    EnergyType sign,
    EnergyCombat Function(EnergyManager) handler,
  ) {
    final combat = handler(_core[sign]);
    combat.execute();
    _updatePreview();
    return combat;
  }

  CombatResult combatRequest(
    Elemental elemental,
    EnergyType sign,
    ValueNotifier<String> message,
  ) {
    final combat = elemental.comabtReply(
      sign,
      (e) => EnergyCombat(source: _core[_current], target: e),
    );

    _updatePreview();
    message.value += combat.message;
    return combat.result;
  }

  EnergyType _updatePreview() => preview.updatePreview(_core, _current);

  static String configToJsonString(
    String name,
    EnergyConfigs configs,
    int current,
  ) {
    final data = {
      'name': name,
      'configs': configs.configToString(),
      'current': current,
    };

    return json.encode(data);
  }

  static String nameFromJson(Map<String, dynamic> json) => json['name'];
  static EnergyConfigs configsFromJson(Map<String, dynamic> json) =>
      EnergyConfigs.fromString(json['configs']);
  static int currentFromJson(Map<String, dynamic> json) => json['current'];

  factory Elemental.fromJson(Map<String, dynamic> json) {
    final String name = Elemental.nameFromJson(json);
    final EnergyConfigs configs = EnergyConfigs.fromString(json['configs']);
    final int current = Elemental.currentFromJson(json);
    return Elemental(baseName: name, configs: configs, current: current);
  }
}

class ElementalEntity extends Elemental with MovableEntity {
  ElementalEntity({
    required super.baseName,
    required super.configs,
    required super.current,
    required EntityType id,
    required int y,
    required int x,
  }) {
    this.id = id;
    this.y = y;
    this.x = x;
  }
}
