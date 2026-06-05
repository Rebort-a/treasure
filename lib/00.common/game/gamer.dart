enum TurnGamerType { front, rear }

extension TurnGamerTypeExtension on TurnGamerType {
  TurnGamerType get opponent =>
      this == TurnGamerType.front ? TurnGamerType.rear : TurnGamerType.front;
}

enum RealGamerType { publisher, reader }
