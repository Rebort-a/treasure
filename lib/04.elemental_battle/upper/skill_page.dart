import 'package:flutter/material.dart';
import 'package:treasure/04.elemental_battle/base/energy.dart';

import '../../00.common/widget/banner/banner_template.dart';
import '../../l10n/strings.dart';
import '../middle/player.dart';
import '../base/skill.dart';

class SkillsPage extends StatefulWidget {
  final NormalPlayer player;
  const SkillsPage({super.key, required this.player});

  @override
  State<SkillsPage> createState() => _SkillsPageState();
}

class _SkillsPageState extends State<SkillsPage> {
  late List<CombatSkill> _showSkills;
  late EnergyType _index;

  @override
  void initState() {
    super.initState();
    _index = widget.player.current;
    _updateSkills();
  }

  _updateSkills() {
    _showSkills = _filterSkills(widget.player.getAppointSkills(_index));
  }

  List<CombatSkill> _filterSkills(List<CombatSkill> skills) {
    List<CombatSkill> showSkills = [];
    for (CombatSkill skill in skills) {
      showSkills.add(skill);
      if (!skill.learned) {
        break;
      }
    }
    return showSkills;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.skill), centerTitle: true),
      body: Column(children: [_buildSkillTree(), _buildNavigationButtons()]),
    );
  }

  Widget _buildSkillTree() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          children: List.generate(_showSkills.length, _buildSkillNode),
        ),
      ),
    );
  }

  Widget _buildSkillNode(int index) {
    return GestureDetector(
      onTap: () => _showPlayerSkill(context, index),
      child: Container(
        margin: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: _showSkills[index].learned ? Colors.blue : Colors.grey,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Center(child: _buildSkillText(_showSkills[index])),
      ),
    );
  }

  Widget _buildSkillText(CombatSkill skill) {
    // String typeText = skill.type == SkillType.active ? '🔥' : '🛡️';
    String typeText = skill.type == SkillType.active ? S.active : S.passive;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          skill.name,
          style: const TextStyle(color: Colors.white, fontSize: 16.0),
        ),
        Text(
          typeText,
          style: const TextStyle(color: Colors.white, fontSize: 12.0),
        ),
      ],
    );
  }

  void _showPlayerSkill(BuildContext context, int index) {
    final AlertDialog pageNavigator = AlertDialog(
      title: Text(_showSkills[index].name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.skillTarget(_showSkills[index].targetType.text)),
          Text(S.skillEffect(_showSkills[index].description)),
        ],
      ),
      actions: [
        if (!_showSkills[index].learned)
          TextButton(
            child: Text(S.learn),
            onPressed: () {
              if (widget.player.experience >= 30) {
                widget.player.experience -= 30;
                BannerTemplate.snackBarDialog(context, S.learnSuccess);
                setState(() {
                  widget.player.upgradeAppointSkill(_index);
                  _updateSkills();
                });
              } else {
                BannerTemplate.snackBarDialog(context, S.notEnoughExp);
              }
              Navigator.pop(context);
            },
          ),
        TextButton(
          child: Text(_showSkills[index].learned ? S.close : S.cancel),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ],
    );

    showDialog<void>(context: context, builder: (context) => pageNavigator);
  }

  Widget _buildNavigationButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildNavigationButton(Icons.arrow_left, () {
          setState(() {
            _index = widget.player.findPreviousAvailable(_index);
            _updateSkills();
          });
        }),
        _buildElementName(),
        _buildNavigationButton(Icons.arrow_right, () {
          setState(() {
            _index = widget.player.findNextAvailable(_index);
            _updateSkills();
          });
        }),
      ],
    );
  }

  Widget _buildNavigationButton(IconData icon, VoidCallback onPressed) {
    return ElevatedButton(onPressed: onPressed, child: Icon(icon));
  }

  Widget _buildElementName() {
    return Text(widget.player.getAppointTypeString(_index));
  }
}
