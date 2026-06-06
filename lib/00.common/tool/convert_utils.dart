import 'dart:ui';

class ConvertUtils {
  static Map<String, int> colorToJson(Color color) => {
    'value': color.toARGB32(),
  };

  static Color colorFromJson(Map<String, dynamic> json) => Color(json['value'] as int);

  static Map<String, double> offsetToJson(Offset offset) => {
    'dx': offset.dx,
    'dy': offset.dy,
  };

  static Offset offsetFromJson(Map<String, dynamic> json) =>
      Offset((json['dx'] as num).toDouble(), (json['dy'] as num).toDouble());
}
