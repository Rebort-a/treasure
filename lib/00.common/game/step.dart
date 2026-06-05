import '../../l10n/strings.dart';

// 游戏进展类型
enum GameStep {
  disconnect,
  connected,
  frontConfig,
  rearWait,
  frontWait,
  rearConfig,
  action,
  gameOver,
}

extension TurnGameStepExtension on GameStep {
  String getExplanation() {
    switch (this) {
      case GameStep.disconnect:
        return S.stepDisconnect;
      case GameStep.connected:
        return S.stepConnected;
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
