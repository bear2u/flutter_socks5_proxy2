/// Result of proxy operations
class ProxyResult {
  /// Whether the operation succeeded
  final bool success;
  
  /// Message describing the result
  final String? message;
  
  /// Additional data (like IP info, stats, etc)
  final Map<String, dynamic>? data;

  const ProxyResult({
    required this.success,
    this.message,
    this.data,
  });

  /// Create a success result
  factory ProxyResult.success([String? message, Map<String, dynamic>? data]) {
    return ProxyResult(
      success: true,
      message: message,
      data: data,
    );
  }

  /// Create a failure result
  factory ProxyResult.failure(String message) {
    return ProxyResult(
      success: false,
      message: message,
    );
  }

  @override
  String toString() {
    return 'ProxyResult(success: $success, message: $message)';
  }
}

/// Information about current proxy connection
class ConnectionInfo {
  final bool isConnected;
  final String? currentHost;
  final int? currentPort;
  final String? currentIp;
  final String? location;

  const ConnectionInfo({
    required this.isConnected,
    this.currentHost,
    this.currentPort,
    this.currentIp,
    this.location,
  });

  /// Create disconnected state
  factory ConnectionInfo.disconnected() {
    return ConnectionInfo(isConnected: false);
  }

  /// Create connected state
  factory ConnectionInfo.connected({
    required String host,
    required int port,
    String? ip,
    String? location,
  }) {
    return ConnectionInfo(
      isConnected: true,
      currentHost: host,
      currentPort: port,
      currentIp: ip,
      location: location,
    );
  }
}