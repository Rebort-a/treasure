import 'dart:math' as math;

/// 三维向量类，用于表示3D空间中的位置、速度、力等
class Vector3 {
  final double x, y, z;
  static const double epsilon = 1e-10;

  const Vector3(this.x, this.y, this.z);

  /// 返回零向量
  factory Vector3.zero() => const Vector3(0, 0, 0);

  /// 带容差的相等比较
  bool equals(Vector3 other, [double tolerance = epsilon]) {
    return (x - other.x).abs() < tolerance &&
        (y - other.y).abs() < tolerance &&
        (z - other.z).abs() < tolerance;
  }

  /// 向量加法
  Vector3 operator +(Vector3 other) =>
      Vector3(x + other.x, y + other.y, z + other.z);

  /// 向量减法
  Vector3 operator -(Vector3 other) =>
      Vector3(x - other.x, y - other.y, z - other.z);

  /// 向量标量乘法
  Vector3 operator *(double scalar) =>
      Vector3(x * scalar, y * scalar, z * scalar);

  /// 向量标量除法
  Vector3 operator /(double scalar) {
    if (scalar.abs() < epsilon) return Vector3.zero();
    return Vector3(x / scalar, y / scalar, z / scalar);
  }

  /// 向量的模的平方
  double get magnitudeSquared => x * x + y * y + z * z;

  /// 向量的模（长度）
  double get magnitude => math.sqrt(magnitudeSquared);

  /// 返回单位向量（归一化）
  Vector3 normalized() {
    final length = magnitude;
    return length < epsilon ? Vector3.zero() : this / length;
  }

  /// 点积运算
  static double dot(Vector3 a, Vector3 b) => a.x * b.x + a.y * b.y + a.z * b.z;

  /// 叉积运算
  static Vector3 cross(Vector3 a, Vector3 b) => Vector3(
    a.y * b.z - a.z * b.y,
    a.z * b.x - a.x * b.z,
    a.x * b.y - a.y * b.x,
  );
}

/// 粒子类
class Particle {
  Vector3 position; // 当前位置
  Vector3 previousPosition; // 上一帧位置 (Verlet积分)
  Vector3 velocity; // 速度
  Vector3 _resultantForce = Vector3.zero(); // 合力
  double mass; // 质量
  final double movementScale; // 运动系数
  final bool verlet;

  Particle({
    required this.position,
    Vector3? velocity,
    this.mass = 1.0,
    this.movementScale = 16,
    this.verlet = false,
  }) : velocity = velocity ?? Vector3.zero(),
       previousPosition = position {
    // 确保质量不为0
    if (mass < Vector3.epsilon) {
      mass = Vector3.epsilon;
    }
  }

  Vector3 get force => _resultantForce;

  /// 清除累积的力
  void clearForce() => _resultantForce = Vector3.zero();

  /// 添加力到粒子
  void addForce(Vector3 force) => _resultantForce = _resultantForce + force;

  /// 根据物理规则更新粒子的位置和速度
  void integrate(double deltaTime) {
    if (verlet) {
      _verletIntegrate(deltaTime);
    } else {
      _eulerIntegrate(deltaTime);
    }
  }

  /// 传统欧拉积分
  void _eulerIntegrate(double deltaTime) {
    // F = ma => a = F/m
    final acceleration = _resultantForce / mass;

    // 更新速度：v = v + a * dt
    velocity = velocity + acceleration * deltaTime;

    // 更新位置：p = p + v * dt * scale
    position = position + velocity * deltaTime * movementScale;
  }

  /// Verlet积分更新位置
  void _verletIntegrate(double deltaTime) {
    // F = ma => a = F/m
    final acceleration = _resultantForce / mass;

    final temp = position;

    // Verlet积分: x_{n+1} = 2x_n - x_{n-1} + a * dt^2
    position =
        position * 2 -
        previousPosition +
        acceleration * (deltaTime * deltaTime) * movementScale;

    previousPosition = temp;

    // 更新速度
    velocity = (position - previousPosition) / deltaTime;
  }
}

/// 弹簧类
class Spring {
  final Particle particleA, particleB;
  final double restLength;
  final double elasticity;
  final double damping;

  Spring(
    this.particleA,
    this.particleB,
    this.restLength, {
    this.elasticity = 25,
    this.damping = 0.4,
  });

  void apply() {
    final Vector3 displacement = particleB.position - particleA.position;
    final double currentLength = displacement.magnitude;

    final Vector3 direction = displacement.normalized(); // 弹簧方向单位向量
    final Vector3 relativeVelocity =
        particleB.velocity - particleA.velocity; // 相对速度

    // 计算阻尼力（与相对速度在弹簧方向上的分量成正比）
    final double dampingForce =
        Vector3.dot(relativeVelocity, direction) * damping;

    // 计算拉伸量
    final double stretch = currentLength - restLength;

    // 胡克定律 + 阻尼：F = -k * Δx - c * v
    final double forceMagnitude = -elasticity * stretch - dampingForce;
    final Vector3 force = direction * forceMagnitude;

    // 作用力与反作用力：A受到反向力，B受到正向力
    particleA.addForce(force * -1);
    particleB.addForce(force);
  }

  /// 当前弹簧长度
  double get currentLength =>
      (particleB.position - particleA.position).magnitude;
}

/// 软筒
class SoftTube {
  final List<Particle> particles = []; // 所有粒子
  final List<Spring> springs = []; // 所有弹簧

  final Vector3 center; // 位置
  final int count; // 数量
  final double radius; // 半径
  final double width; // 宽度

  final double elasticity; // 弹性系数
  final double damping; // 阻尼系数

  SoftTube({
    required this.center,
    this.count = 80,
    this.radius = 32,
    this.width = 16,
    this.elasticity = 25,
    this.damping = 0.4,
  }) {
    _buildTubeStructure();
  }

  /// 构建圆柱的物理结构（粒子和弹簧网络）
  void _buildTubeStructure() {
    particles.clear();
    springs.clear();

    // 创建粒子
    for (int i = 0; i < count; i++) {
      final angle = 2 * math.pi / count * i; // 角度
      final offset = Vector3(
        (i % 2 == 0 ? width : -width), // x方向：交替正负创建宽度
        radius * math.sin(angle), // y坐标
        radius * math.cos(angle), // z坐标
      );
      final position = center + offset;

      particles.add(Particle(position: position));
    }

    // 创建弹簧连接：构建三角形网格以增加稳定性
    for (int i = 0; i < count; i++) {
      final neighbor1 = (i + 1) % count; // 相邻粒子
      final neighbor2 = (i + 2) % count; // 隔一个粒子
      final opposite = (i + count ~/ 2) % count; // 对面粒子

      // 相邻连接
      springs.add(_createSpring(i, neighbor1));
      springs.add(_createSpring(i, neighbor2));

      // 对面粒子的长距离连接
      springs.add(_createSpring(i, opposite));
    }
  }

  /// 在两个粒子间创建弹簧
  Spring _createSpring(int particleIndexA, int particleIndexB) {
    final particleA = particles[particleIndexA];
    final particleB = particles[particleIndexB];
    final restLength = (particleB.position - particleA.position).magnitude;
    return Spring(
      particleA,
      particleB,
      restLength,
      elasticity: elasticity,
      damping: damping,
    );
  }

  /// 对所有粒子施加力
  void applyForce(Vector3 force) {
    for (final particle in particles) {
      particle.addForce(force);
    }
  }

  /// 执行物理模拟的一步
  void simulateStep(
    double deltaTime,
    Vector3 externalForce,
    void Function(Particle) onCollision,
  ) {
    // 1. 清除所有粒子的累积力
    for (final particle in particles) {
      particle.clearForce();
    }

    // 2. 应用内力
    for (final spring in springs) {
      spring.apply();
    }

    // 3. 应用外力
    for (final particle in particles) {
      particle.addForce(externalForce);
    }

    // 4. 积分更新
    for (final particle in particles) {
      particle.integrate(deltaTime);
      onCollision(particle);
    }
  }

  /// 获取四边形中心点用于深度排序
  Vector3 getQuadCenter(int index) {
    final int particleCount = particles.length;
    final currentIndex = index;
    final nextIndex = (index + 1) % particleCount;
    final oppositeIndex1 = (index + 3) % particleCount;
    final oppositeIndex2 = (index + 2) % particleCount;

    final p0 = particles[currentIndex].position;
    final p1 = particles[nextIndex].position;
    final p2 = particles[oppositeIndex1].position;
    final p3 = particles[oppositeIndex2].position;

    return Vector3(
      (p0.x + p1.x + p2.x + p3.x) / 4,
      (p0.y + p1.y + p2.y + p3.y) / 4,
      (p0.z + p1.z + p2.z + p3.z) / 4,
    );
  }

  // 物体的总体能量
  double get kineticEnergy => particles
      .map(
        (particle) =>
            0.5 *
            particle.mass *
            particle.velocity.magnitude *
            particle.velocity.magnitude,
      )
      .reduce((a, b) => a + b);
}
