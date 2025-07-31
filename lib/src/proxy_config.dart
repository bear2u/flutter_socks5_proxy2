/// Configuration for SOCKS5 proxy connection
class ProxyConfig {
  /// Proxy server host (domain or IP address)
  /// Examples: "proxy.example.com", "52.78.114.137"
  final String host;
  
  /// Proxy server port
  /// Default SOCKS5 port is 1080, but commonly 8388 for Shadowsocks
  final int port;
  
  /// Optional username for proxy authentication
  final String? username;
  
  /// Optional password for proxy authentication
  final String? password;
  
  /// Connection timeout in seconds
  final int timeoutSeconds;
  
  /// Enable detailed logging
  final bool enableLogging;

  const ProxyConfig({
    required this.host,
    required this.port,
    this.username,
    this.password,
    this.timeoutSeconds = 30,
    this.enableLogging = false,
  });

  /// Create a simple configuration with just host and port
  factory ProxyConfig.simple(String host, int port) {
    return ProxyConfig(host: host, port: port);
  }

  Map<String, dynamic> toMap() {
    return {
      'host': host,
      'port': port,
      'username': username,
      'password': password,
      'timeoutSeconds': timeoutSeconds,
      'enableLogging': enableLogging,
    };
  }

  @override
  String toString() {
    return 'ProxyConfig(host: $host, port: $port)';
  }
}