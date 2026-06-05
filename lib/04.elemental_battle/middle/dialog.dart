import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import 'elemental.dart';
import '../base/energy.dart';
import '../base/skill.dart';

class ElementalDialog {
  static void showSelectEnergyDialog({
    required BuildContext context,
    required Elemental elemental,
    required void Function(EnergyType) onSelected,
    required bool available,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(S.selectEnergy),
          content: Container(
            // 设置最大高度，超过时可滚动
            constraints: const BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(EnergyType.values.length, (index) {
                  EnergyType type = EnergyType.values[index];

                  // 仅处理enable为true的Energy
                  if (!elemental.getAppointAptitude(type)) {
                    return const SizedBox();
                  }

                  String name = elemental.getAppointName(type);
                  int health = elemental.getAppointHealth(type);
                  int capacity = elemental.getAppointCapacity(type);
                  return Column(
                    children: [
                      ElevatedButton(
                        onPressed: available
                            ? health > 0
                                  ? () {
                                      onSelected(EnergyType.values[index]);
                                      Navigator.pop(context);
                                    }
                                  : null
                            : () {
                                onSelected(EnergyType.values[index]);
                                Navigator.pop(context);
                              },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: health > 0
                              ? Colors.white
                              : Colors.black,
                          backgroundColor: health > 0
                              ? Colors.blue
                              : Colors.grey,
                          disabledBackgroundColor: Colors.grey,
                        ),
                        child: Text('$name $health/$capacity'),
                      ),
                      const SizedBox(height: 5), // 添加间隙
                    ],
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }

  static void showSelectSkillDialog({
    required BuildContext context,
    required List<CombatSkill> skills,
    required void Function(int) handleSkill,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(S.selectSkill),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: skills
                .asMap()
                .entries
                .where(
                  (entry) =>
                      (entry.value.type == SkillType.active) &&
                      entry.value.learned,
                )
                .map((entry) {
                  int index = entry.key;
                  CombatSkill skill = entry.value;
                  return Column(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          handleSkill(index);
                        },
                        child: Text(skill.name),
                      ),
                      const SizedBox(height: 5), // 添加间隙
                    ],
                  );
                })
                .toList(),
          ),
        );
      },
    );
  }

  static void showUpgradeDialog({
    required BuildContext context,
    required bool Function() before,
    required VoidCallback after,
    required void Function(int index, AttributeType attribute) upgrade,
  }) {
    if (before()) {
      int chosenElement = -1;
      AttributeType chosenAttribute = AttributeType.hp;

      showDialog(
        context: context,
        builder: (BuildContext context) {
          List<int> elementsForDialog = List.generate(
            EnergyType.values.length,
            (index) => index,
          );
          List<int> attributesForDialog = List.generate(
            AttributeType.values.length,
            (index) => index,
          );

          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                content: Container(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(S.chooseEnergy),
                        ...elementsForDialog.map(
                          (elementIndex) => ListTile(
                            title: Text(
                              EnergyType.values[elementIndex].text,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            onTap: () {
                              setState(() {
                                chosenElement = elementIndex;
                              });
                            },
                            trailing: chosenElement == elementIndex
                                ? const Icon(Icons.check)
                                : null,
                            style: chosenElement == elementIndex
                                ? ListTileStyle.drawer
                                : ListTileStyle.list,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (chosenElement != -1) ...[
                          Text(S.chooseAttribute),
                          ...attributesForDialog.map(
                            (attributeIndex) => ListTile(
                              title: Text(
                                AttributeType.values[attributeIndex].text,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              onTap: () {
                                setState(() {
                                  chosenAttribute =
                                      AttributeType.values[attributeIndex];
                                });
                              },
                              trailing: chosenAttribute.index == attributeIndex
                                  ? const Icon(Icons.check)
                                  : null,
                              style: chosenAttribute.index == attributeIndex
                                  ? ListTileStyle.drawer
                                  : ListTileStyle.list,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    child: Text(S.cancel),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  TextButton(
                    onPressed: () {
                      if (chosenElement != -1) {
                        upgrade(chosenElement, chosenAttribute);
                      }
                      Navigator.pop(context);
                    },
                    child: Text(S.ok),
                  ),
                ],
              );
            },
          );
        },
      ).then((value) {
        after();
      });
    }
  }
}
