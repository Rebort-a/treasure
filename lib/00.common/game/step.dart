import '../l10n/strings.dart';

// 游戏进展类型
enum GameStep {
  start,
  frontConfig,
  rearWait,
  frontWait,
  rearConfig,
  synchronizing,
  action,
  gameOver,
}

extension TurnGameStepExtension on GameStep {
  String getExplanation() {
    switch (this) {
      case GameStep.start:
        return S.matchingPlayers;
      case GameStep.synchronizing:
        return S.wait;
      case GameStep.frontConfig:
        return S.stepFrontConfig;
      case GameStep.rearWait:
        return S.stepRearWait;
      case GameStep.frontWait:
        return S.stepFrontWait;
      case GameStep.rearConfig:
        return S.stepRearConfig;
      case GameStep.action:
        return S.stepAction;
      case GameStep.gameOver:
        return S.stepGameOver;
    }
  }
}
