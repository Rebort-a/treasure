import 'dart:math' as math;
import 'vector.dart';

/// 4x4 浮点矩阵类（列主序存储）
/// 核心用途：3D图形变换（视图矩阵、投影矩阵、坐标变换等）
/// 存储格式：[c0r0, c0r1, c0r2, c0r3, c1r0, c1r1, c1r2, c1r3, c2r0, c2r1, c2r2, c2r3, c3r0, c3r1, c3r2, c3r3]
/// 其中 c=列（column），r=行（row），索引范围 0-3
class ColMat4 {
  // 存储矩阵元素的浮点列表（长度固定为16）
  final List<double> _values;

  // ========================== 构造函数 ==========================
  /// 创建全零矩阵（所有元素为0.0）
  ColMat4.zero() : _values = List.filled(16, 0.0);

  /// 创建单位矩阵（对角线元素为1.0，其余为0.0）
  /// 单位矩阵特性：与任意矩阵相乘后，原矩阵保持不变
  ColMat4.identity() : _values = List.filled(16, 0.0) {
    _values[0] = 1.0; // 第0列第0行（c0r0）
    _values[5] = 1.0; // 第1列第1行（c1r1）
    _values[10] = 1.0; // 第2列第2行（c2r2）
    _values[15] = 1.0; // 第3列第3行（c3r3）
  }

  /// 从浮点列表初始化矩阵
  /// [list]：输入的浮点列表，不足16个元素时补0.0，超出部分忽略
  ColMat4.fromList(List<double> list) : _values = List.filled(16, 0.0) {
    final copyLength = list.length < 16 ? list.length : 16;
    for (int i = 0; i < copyLength; i++) {
      _values[i] = list[i];
    }
  }

  // ========================== 元素访问 ==========================
  /// 通过索引（0-15）访问矩阵元素（列主序）
  /// 索引计算规则：index = 列号 * 4 + 行号
  double operator [](int index) {
    _validateIndex(index);
    return _values[index];
  }

  /// 通过索引（0-15）设置矩阵元素（列主序）
  void operator []=(int index, double value) {
    _validateIndex(index);
    _values[index] = value;
  }

  /// 通过“列号+行号”获取元素（更直观的访问方式）
  /// [column]：列号（0-3），[row]：行号（0-3）
  double getElement(int column, int row) {
    _validateColumnRow(column, row);
    return _values[column * 4 + row];
  }

  /// 通过“列号+行号”设置元素
  /// [column]：列号（0-3），[row]：行号（0-3），[value]：要设置的浮点值
  void setElement(int column, int row, double value) {
    _validateColumnRow(column, row);
    _values[column * 4 + row] = value;
  }

  // ========================== 核心运算 ==========================
  /// 矩阵乘法（this × other）
  /// 结果矩阵的元素 = this的行向量 · other的列向量
  ColMat4 operator *(ColMat4 other) {
    final result = ColMat4.zero();
    for (int col = 0; col < 4; col++) {
      // 遍历结果矩阵的列
      for (int row = 0; row < 4; row++) {
        // 遍历结果矩阵的行
        double sum = 0.0;
        // 计算行与列的点积（累加4个元素的乘积）
        for (int i = 0; i < 4; i++) {
          sum += getElement(i, row) * other.getElement(col, i);
        }
        result.setElement(col, row, sum);
      }
    }
    return result;
  }

  /// 矩阵与4维向量相乘（变换4D向量）
  /// [vector]：输入的4D向量，返回变换后的新4D向量
  Vector4 multiplyVector4(Vector4 vector) {
    return Vector4(
      // x分量：向量与矩阵第0列的点积
      vector.x * _values[0] +
          vector.y * _values[4] +
          vector.z * _values[8] +
          vector.w * _values[12],
      // y分量：向量与矩阵第1列的点积
      vector.x * _values[1] +
          vector.y * _values[5] +
          vector.z * _values[9] +
          vector.w * _values[13],
      // z分量：向量与矩阵第2列的点积
      vector.x * _values[2] +
          vector.y * _values[6] +
          vector.z * _values[10] +
          vector.w * _values[14],
      // w分量：向量与矩阵第3列的点积
      vector.x * _values[3] +
          vector.y * _values[7] +
          vector.z * _values[11] +
          vector.w * _values[15],
    );
  }

  /// 矩阵标量乘法（矩阵所有元素 × 标量）
  /// [scalar]：要相乘的浮点数，返回新的矩阵
  ColMat4 multiplyScalar(double scalar) {
    final result = ColMat4.zero();
    for (int i = 0; i < 16; i++) {
      result._values[i] = _values[i] * scalar;
    }
    return result;
  }

  /// 计算矩阵的逆矩阵（伴随矩阵法）
  /// 逆矩阵特性：原矩阵 × 逆矩阵 = 单位矩阵
  /// 注意：若矩阵行列式绝对值<1e-10（奇异矩阵），返回全零矩阵（避免除以零）
  ColMat4 inverse() {
    final determinantValue = determinant();
    // 处理奇异矩阵（行列式接近零，无有效逆矩阵）
    if (determinantValue.abs() < 1e-10) {
      return ColMat4.zero();
    }
    // 逆矩阵 = 伴随矩阵 × (1/行列式)
    return adjugate().multiplyScalar(1.0 / determinantValue);
  }

  /// 计算4x4矩阵的行列式（用于逆矩阵计算）
  /// 行列式计算逻辑：按第0行展开，递归计算3x3子矩阵的行列式
  double determinant() {
    // 提取矩阵元素（按列主序映射：_floatValues[列×4+行]）
    final a00 = getElement(0, 0),
        a01 = getElement(1, 0),
        a02 = getElement(2, 0),
        a03 = getElement(3, 0);
    final a10 = getElement(0, 1),
        a11 = getElement(1, 1),
        a12 = getElement(2, 1),
        a13 = getElement(3, 1);
    final a20 = getElement(0, 2),
        a21 = getElement(1, 2),
        a22 = getElement(2, 2),
        a23 = getElement(3, 2);
    final a30 = getElement(0, 3),
        a31 = getElement(1, 3),
        a32 = getElement(2, 3),
        a33 = getElement(3, 3);

    // 按第0行展开计算行列式（符号交替：+、-、+、-）
    return a00 * _det3x3(a11, a12, a13, a21, a22, a23, a31, a32, a33) -
        a01 * _det3x3(a10, a12, a13, a20, a22, a23, a30, a32, a33) +
        a02 * _det3x3(a10, a11, a13, a20, a21, a23, a30, a31, a33) -
        a03 * _det3x3(a10, a11, a12, a20, a21, a22, a30, a31, a32);
  }

  /// 计算伴随矩阵（逆矩阵计算的中间步骤）
  /// 伴随矩阵 = 余子式矩阵的转置（余子式 = 代数余子式，包含符号）
  ColMat4 adjugate() {
    // 提取矩阵元素（按列主序映射）
    final a00 = getElement(0, 0),
        a01 = getElement(1, 0),
        a02 = getElement(2, 0),
        a03 = getElement(3, 0);
    final a10 = getElement(0, 1),
        a11 = getElement(1, 1),
        a12 = getElement(2, 1),
        a13 = getElement(3, 1);
    final a20 = getElement(0, 2),
        a21 = getElement(1, 2),
        a22 = getElement(2, 2),
        a23 = getElement(3, 2);
    final a30 = getElement(0, 3),
        a31 = getElement(1, 3),
        a32 = getElement(2, 3),
        a33 = getElement(3, 3);

    // 第一步：计算所有2x2子矩阵的行列式（用于后续3x3行列式计算）
    final b00 = a00 * a11 - a01 * a10;
    final b01 = a00 * a12 - a02 * a10;
    final b02 = a00 * a13 - a03 * a10;
    final b03 = a01 * a12 - a02 * a11;
    final b04 = a01 * a13 - a03 * a11;
    final b05 = a02 * a13 - a03 * a12;
    final b06 = a20 * a31 - a21 * a30;
    final b07 = a20 * a32 - a22 * a30;
    final b08 = a20 * a33 - a23 * a30;
    final b09 = a21 * a32 - a22 * a31;
    final b10 = a21 * a33 - a23 * a31;
    final b11 = a22 * a33 - a23 * a32;

    // 第二步：计算余子式（符号交替），并组成伴随矩阵（列主序）
    return ColMat4.fromList([
      // 第0列：det00（+）、det10（-）、det20（+）、det30（-）
      (a11 * b11 - a12 * b10 + a13 * b09),
      -(a01 * b11 - a02 * b10 + a03 * b09),
      (a01 * b05 - a02 * b04 + a03 * b03),
      -(a01 * b08 - a02 * b07 + a03 * b06),

      // 第1列：det01（-）、det11（+）、det21（-）、det31（+）
      -(a10 * b11 - a12 * b08 + a13 * b07),
      (a00 * b11 - a02 * b08 + a03 * b07),
      -(a00 * b05 - a02 * b02 + a03 * b01),
      (a00 * b08 - a02 * b05 + a03 * b04),

      // 第2列：det02（+）、det12（-）、det22（+）、det32（-）
      (a10 * b10 - a11 * b08 + a13 * b06),
      -(a00 * b10 - a01 * b08 + a03 * b06),
      (a00 * b04 - a01 * b02 + a03 * b00),
      -(a00 * b07 - a01 * b05 + a03 * b03),

      // 第3列：det03（-）、det13（+）、det23（-）、det33（+）
      -(a10 * b09 - a11 * b07 + a12 * b06),
      (a00 * b09 - a01 * b07 + a02 * b06),
      -(a00 * b03 - a01 * b01 + a02 * b00),
      (a00 * b06 - a01 * b04 + a02 * b03),
    ]);
  }

  // ========================== 静态工厂方法（特定矩阵创建） ==========================
  /// 创建左手坐标系的视图矩阵（View Matrix）
  /// 作用：将世界坐标转换为相机（眼）坐标
  /// [eye]：相机位置（眼点），[target]：相机看向的目标点，[up]：世界空间的上方向（单位向量）
  static ColMat4 lookAtLH(Vector3 eye, Vector3 target, Vector3Unit up) {
    // 1. 计算相机的前向向量（Z轴，指向目标，左手系中Z轴向里）
    final forward = (target - eye).normalized;
    // 2. 计算相机的右向向量（X轴，垂直于上方向和前向向量）
    final right = up.cross(forward).normalized;
    // 3. 重新计算相机的上方向（Y轴，垂直于前向和右向，确保三轴正交）
    final newUp = forward.cross(right).normalized;

    // 视图矩阵公式（左手系）：旋转部分（正交矩阵）+ 平移部分（-eye在相机轴上的投影）
    return ColMat4.fromList([
      right.x, newUp.x, forward.x, 0.0, // 第0列（右向向量）
      right.y, newUp.y, forward.y, 0.0, // 第1列（上向向量）
      right.z, newUp.z, forward.z, 0.0, // 第2列（前向向量）
      -right.dot(eye), -newUp.dot(eye), -forward.dot(eye), 1.0, // 第3列（平移分量）
    ]);
  }

  /// 创建左手坐标系的透视投影矩阵（Perspective Projection Matrix）
  /// 作用：将相机坐标转换为裁剪空间坐标，实现近大远小效果
  /// [fovY]：垂直视场角（弧度），[aspect]：宽高比（窗口宽/窗口高）
  /// [near]：近裁剪面距离（必须>0），[far]：远裁剪面距离（必须>near）
  static ColMat4 perspectiveLH(
    double fovY,
    double aspect,
    double near,
    double far,
  ) {
    // 1. 计算垂直方向的缩放因子（基于视场角）
    final verticalScale = 1.0 / math.tan(fovY * 0.5);
    // 2. 计算水平方向的缩放因子（基于宽高比，确保正方形像素）
    final horizontalScale = verticalScale / aspect;
    // 3. 计算深度范围压缩因子（将[near, far]映射到[0, 1]，左手系）
    final depthRange = far / (far - near);

    // 透视投影矩阵公式（左手系）：缩放+深度变换，无平移
    return ColMat4.fromList([
      horizontalScale, 0.0, 0.0, 0.0, // 第0列（X轴缩放）
      0.0, verticalScale, 0.0, 0.0, // 第1列（Y轴缩放）
      0.0, 0.0, depthRange, 1.0, // 第2列（深度变换：Z→W）
      0.0, 0.0, -depthRange * near, 0.0, // 第3列（深度偏移）
    ]);
  }

  // ========================== 私有工具方法 ==========================
  /// 计算3x3矩阵的行列式（用于4x4行列式展开）
  /// 参数顺序：a b c; d e f; g h i（3x3矩阵的行优先元素）
  static double _det3x3(
    double a,
    double b,
    double c,
    double d,
    double e,
    double f,
    double g,
    double h,
    double i,
  ) {
    // 3x3行列式公式：a(ei-fh) - b(di-fg) + c(dh-eg)
    return a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g);
  }

  /// 校验索引是否在0-15范围内（防止越界）
  void _validateIndex(int index) {
    if (index < 0 || index >= 16) {
      throw ArgumentError(
        'ColMat4 index must be between 0 and 15, current value: $index',
      );
    }
  }

  /// 校验列号和行号是否在0-3范围内（防止越界）
  void _validateColumnRow(int column, int row) {
    if (column < 0 || column >= 4) {
      throw ArgumentError(
        'ColMat4 column index must be between 0 and 3, current value: $column',
      );
    }
    if (row < 0 || row >= 4) {
      throw ArgumentError(
        'ColMat4 row index must be between 0 and 3, current value: $row',
      );
    }
  }
}

/// 4x4 整数矩阵类（列主序存储）
/// 核心用途：整数精度的坐标变换（如网格计算、像素对齐变换）
/// 存储格式与Matrix一致，仅元素类型为int，不支持浮点运算（需转换为Matrix后使用）
class ColMat4Int {
  // 存储矩阵元素的整数列表（长度固定为16）
  final List<int> _values;

  // ========================== 构造函数 ==========================
  /// 创建全零整数矩阵（所有元素为0）
  ColMat4Int.zero() : _values = List.filled(16, 0);

  /// 创建整数单位矩阵（对角线元素为1，其余为0）
  ColMat4Int.identity() : _values = List.filled(16, 0) {
    _values[0] = 1; // 第0列第0行（c0r0）
    _values[5] = 1; // 第1列第1行（c1r1）
    _values[10] = 1; // 第2列第2行（c2r2）
    _values[15] = 1; // 第3列第3行（c3r3）
  }

  /// 从整数列表初始化矩阵
  /// [list]：输入的整数列表，不足16个元素时补0，超出部分忽略
  ColMat4Int.fromList(List<int> list) : _values = List.filled(16, 0) {
    final copyLength = list.length < 16 ? list.length : 16;
    for (int i = 0; i < copyLength; i++) {
      _values[i] = list[i];
    }
  }

  // ========================== 元素访问 ==========================
  /// 通过索引（0-15）访问整数矩阵元素（列主序）
  int operator [](int index) {
    _validateIndex(index);
    return _values[index];
  }

  /// 通过索引（0-15）设置整数矩阵元素（列主序）
  void operator []=(int index, int value) {
    _validateIndex(index);
    _values[index] = value;
  }

  // ========================== 核心功能 ==========================
  /// 转换为浮点矩阵Matrix
  /// 作用：将整数矩阵转换为支持浮点运算的矩阵（如逆矩阵、投影变换）
  ColMat4 toMatrix() {
    return ColMat4.fromList(_values.map((value) => value.toDouble()).toList());
  }

  // ========================== 私有工具方法 ==========================
  /// 校验索引是否在0-15范围内（防止越界）
  void _validateIndex(int index) {
    if (index < 0 || index >= 16) {
      throw ArgumentError(
        'Integer matrix index must be between 0 and 15, current value: $index',
      );
    }
  }
}
