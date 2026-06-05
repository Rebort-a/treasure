/// 网络传输方案
enum NetworkMode {
  /// TCP + UDP：原生端专用，零外部依赖，Web 端无联机
  socket,

  /// WebSocket：全平台统一，Web 端可通过 IP 加入房间
  webSocket,
}

/// 当前使用的网络方案
const NetworkMode networkMode = NetworkMode.webSocket;
