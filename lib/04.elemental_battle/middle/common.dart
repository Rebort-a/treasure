// 战斗结果类型
enum ResultType { continued, victory, defeat, escape, draw }

// 战斗行为类型
enum ConationType { attack, escape, parry, skill }

// 战斗行为数据结构
class GameAction {
  final int actionIndex;
  final int targetIndex;

  GameAction({required this.actionIndex, required this.targetIndex});

  Map<String, dynamic> toJson() {
    return {'actionIndex': actionIndex, 'targetIndex': targetIndex};
  }

  static GameAction fromJson(Map<String, dynamic> json) {
    return GameAction(
      actionIndex: json['actionIndex'],
      targetIndex: json['targetIndex'],
    );
  }
}
