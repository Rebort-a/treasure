import 'block.dart';
import 'constant.dart';
import 'vector.dart';
import 'collider.dart';

/// 玩家角色
class Player {
  Vector3 _position; // 位置
  Vector3Unit orientation; // 朝向
  Vector3 velocity; // 速度
  bool isGrounded; // 是否在地面上
  MovedBoxCollider collider; // 碰撞盒

  Player({required Vector3 position})
    : _position = position,
      orientation = Vector3Unit.forward,
      velocity = Vector3.zero,
      isGrounded = true,
      collider = MovedBoxCollider(
        position: position,
        size: Vector3(
          Constants.playerWidth,
          Constants.playerHeight,
          Constants.playerWidth,
        ),
      );

  /// 获取前进单位
  Vector2 get forwardUnit => Vector2(orientation.x, orientation.z);

  /// 获取右向单位，长度与forwardUnit一致，方向向右旋转九十度
  Vector2 get rightUnit => Vector2(orientation.z, -orientation.x);

  /// 获取俯仰角正弦值
  double get pitch => orientation.y;

  Vector3 get position => _position;

  set position(Vector3 value) {
    _position = value;
    collider.updatePosition(value);
  }

  /// 更新玩家状态
  void update(double deltaTime, List<Block> blocks) {
    // 应用重力（不在地面上时）
    if (!isGrounded) {
      velocity = Vector3(
        velocity.x,
        velocity.y - Constants.gravity * deltaTime,
        velocity.z,
      );
    }

    // 限制下落速度
    if (velocity.y < -Constants.maxFallSpeed) {
      velocity = velocity.appointY(-Constants.maxFallSpeed);
    }

    // 应用速度更新位置
    position += velocity * deltaTime;

    // 重置地面状态条件：
    // 1. 跳跃上升中（velocity.y > 1）
    // 2. 脚下无支撑方块（方块被摧毁后应下落）
    if (velocity.y > 1.0) {
      isGrounded = false;
    } else if (isGrounded) {
      final footY = position.y - Constants.playerHeight * 0.75 - 0.1;
      final footPos = Vector3Int(
        (position.x / 2).round() * 2,
        (footY / 2).floor() * 2,
        (position.z / 2).round() * 2,
      );
      bool hasSupport = false;
      for (final block in blocks) {
        if (block.type.isPenetrate) continue;
        if (block.position == footPos) {
          hasSupport = true;
          break;
        }
      }
      if (!hasSupport) isGrounded = false;
    }

    // 检测与方块的碰撞
    for (final block in blocks) {
      if (block.type.isPenetrate) continue;

      if (collider.checkFixedBox(block.collider)) {
        _handleCollision(block.collider);
      }
    }
  }

  /// 处理碰撞
  void _handleCollision(FixedBoxCollider block) {
    final resolution = collider.resolveFixedBox(block);

    position += resolution;

    // 根据碰撞方向更新状态
    if (resolution.y > 0) {
      isGrounded = true;
      velocity = velocity.appointY(0);
    } else if (resolution.y < 0) {
      velocity = velocity.appointY(0);
    }

    if (resolution.x != 0) velocity = velocity.appointX(0);
    if (resolution.z != 0) velocity = velocity.appointZ(0);
  }

  /// 跳跃
  void jump() {
    if (isGrounded) {
      isGrounded = false;
      velocity = velocity.appointY(Constants.jumpVelocity);
    }
  }

  /// 移动 Vector2 input代表在水平面上的速度
  void move(Vector2 input, double speed) {
    if (input.isZero) {
      velocity = Vector3(
        velocity.x * Constants.friction,
        velocity.y,
        velocity.z * Constants.friction,
      );
    } else {
      final moveDirection = rightUnit * input.x + forwardUnit * input.y;
      velocity = Vector3(
        moveDirection.x * speed,
        velocity.y,
        moveDirection.y * speed,
      );
    }
  }

  /// 旋转视角 deltaYaw代表偏移角度，deltaPitch代表俯仰角度
  void rotateView(double deltaYaw, double deltaPitch) {
    // 偏航：在XZ平面上旋转
    if (deltaYaw != 0) {
      // 使用单位向量表示旋转角度
      final rotation = UnitVector2.fromAngle(deltaYaw);

      // 绕Y轴旋转朝向向量
      orientation = Vector3Unit.fromVector3(
        orientation.rotateAroundY(rotation),
      );
    }

    // 俯仰：直接修改Y分量
    if (deltaPitch != 0) {
      double newY = (pitch + deltaPitch).clamp(
        -Constants.pitchLimit,
        Constants.pitchLimit,
      );
      orientation = orientation.appointY(newY);
    }
  }
}
