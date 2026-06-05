import 'package:http/http.dart' as http;

/// 从服务器获取房间信息（全平台统一实现）
Future<String?> fetchRoomInfo(String host, int port) async {
  try {
    final response = await http.Client()
        .get(Uri.parse('http://$host:$port/'))
        .timeout(const Duration(seconds: 2));
    if (response.statusCode == 200) {
      return response.body;
    }
  } catch (_) {}
  return null;
}
