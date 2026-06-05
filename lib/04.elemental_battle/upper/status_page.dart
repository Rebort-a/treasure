import 'package:flutter/material.dart';
import 'package:treasure/04.elemental_battle/base/energy.dart';

import '../../l10n/strings.dart';
import '../base/effect.dart';
import '../middle/elemental.dart';
import '../middle/player.dart';

class StatusPage extends StatefulWidget {
  final Elemental elemental;
  const StatusPage({super.key, required this.elemental});

  @override
  State<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  late EnergyType _index;

  @override
  void initState() {
    super.initState();
    _index = widget.elemental.current;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.status), centerTitle: true),
      body: Column(children: [_buildStatusInfo(), _buildNavigationButtons()]),
    );
  }

  Widget _buildStatusInfo() {
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildNameInfo(),
          const Divider(),
          _buildAttributeInfo(),
          const Divider(),
          _buildSkillsList(),
          const Divider(),
          _buildEffectsList(),
        ],
      ),
    );
  }

  Widget _buildNameInfo() {
    return Column(
      children: [
        Text(
          widget.elemental.baseName,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (widget.elemental is NormalPlayer)
          Text(
            S.exp((widget.elemental as NormalPlayer).experience),
            style: Theme.of(context).textTheme.labelLarge,
          ),
      ],
    );
  }

  Widget _buildAttributeInfo() {
    return Column(
      children: [
        _buildTextItem(S.lv(widget.elemental.getAppointLevel(_index))),
        _buildTextItem(S.hpCap(widget.elemental.getAppointCapacity(_index))),
        _buildTextItem(
          S.baseAtk(widget.elemental.getAppointAttackBase(_index)),
        ),
        _buildTextItem(
          S.baseDef(widget.elemental.getAppointDefenceBase(_index)),
        ),
        const Divider(),
        _buildTextItem(S.curHp(widget.elemental.getAppointHealth(_index))),
        _buildTextItem(S.curAtk(widget.elemental.getAppointAttack(_index))),
        _buildTextItem(S.curDef(widget.elemental.getAppointDefence(_index))),
      ],
    );
  }

  Widget _buildSkillsList() {
    return ListTile(
      title: Text(S.masteredSkills, style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Column(
        children: widget.elemental
            .getAppointSkills(_index)
            .where((skill) => skill.learned)
            .map((skill) => _buildTextItem(skill.name))
            .toList(),
      ),
    );
  }

  Widget _buildEffectsList() {
    return ListTile(
      title: Text(S.activeEffects, style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Column(
        children: widget.elemental
            .getAppointEffects(_index)
            .where(
              (effect) =>
                  (effect.type == EffectType.infinite || effect.times > 0),
            )
            .map(
              (effect) => _buildTextItem(
                '${effect.id} ${effect.type} ${effect.value} ${effect.times}',
              ),
            )
            .toList(),
      ),
    );
  }

  // 自定义文本组件，用于统一文本展示的样式
  Widget _buildTextItem(String text) {
    return Text(text, style: const TextStyle(fontSize: 16)); // 可以根据需要调整样式
  }

  Widget _buildNavigationButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildNavigationButton(Icons.arrow_left, () {
          setState(() {
            _index = widget.elemental.findPreviousAvailable(_index);
          });
        }),
        _buildElementName(),
        _buildNavigationButton(Icons.arrow_right, () {
          setState(() {
            _index = widget.elemental.findNextAvailable(_index);
          });
        }),
      ],
    );
  }

  Widget _buildNavigationButton(IconData icon, VoidCallback onPressed) {
    return ElevatedButton(onPressed: onPressed, child: Icon(icon));
  }

  Widget _buildElementName() {
    return Text(widget.elemental.getAppointTypeString(_index));
  }
}
