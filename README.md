# Flutter SOCKS5 Proxy

A simple Flutter package for connecting to SOCKS5 proxy servers with easy-to-use connect/disconnect API.

## Features

- 🚀 Simple API - Just `connect()` and `disconnect()`
- 🌐 Domain and IP support - Use either domain names or IP addresses
- 📱 Android support - Native implementation using OkHttp
- 🔄 Dynamic configuration - Change proxy settings at runtime
- 📊 Statistics tracking - Monitor proxy usage
- 🔐 Optional authentication - Username/password support

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_socks5_proxy: ^1.0.0
```

## Usage

### Basic Example

```dart
import 'package:flutter_socks5_proxy/flutter_socks5_proxy.dart';

// Create proxy instance
final proxy = Socks5Proxy();

// Connect to proxy server
final result = await proxy.connect('proxy.example.com', 8388);
if (result.success) {
  print('Connected!');
}

// Test connection
final test = await proxy.testConnection();
print('Current IP: ${test.data?['ip']}');

// Make HTTP requests (automatically routed through proxy)
final response = await proxy.request('https://api.example.com/data');

// Disconnect
await proxy.disconnect();
```

### Using Domain Names (Recommended for China)

```dart
// Using domain instead of IP to bypass blocking
await proxy.connect('api-service.yourdomain.com', 8388);

// Multiple regional proxies
final proxies = [
  ProxyConfig.simple('proxy-hk.yourdomain.com', 8388),  // Hong Kong
  ProxyConfig.simple('proxy-sg.yourdomain.com', 8388),  // Singapore
  ProxyConfig.simple('proxy-jp.yourdomain.com', 8388),  // Japan
];

// Connect to first available
for (final config in proxies) {
  final result = await proxy.connectWithConfig(config);
  if (result.success) break;
}
```

### Blockchain RPC Example

```dart
// Connect to proxy
await proxy.connect('proxy.example.com', 8388);

// Make blockchain RPC calls
final blockNumber = await proxy.getBlockNumber('https://eth.llamarpc.com');
print('Latest block: $blockNumber');

final balance = await proxy.getBalance(
  'https://eth.llamarpc.com',
  '0xYourAddress',
);
print('Balance: $balance');
```

### Advanced Configuration

```dart
// With authentication
await proxy.connect(
  'proxy.example.com',
  8388,
  username: 'user',
  password: 'pass',
  enableLogging: true,  // Enable debug logs
);

// Using ProxyConfig
final config = ProxyConfig(
  host: 'proxy.example.com',
  port: 8388,
  timeoutSeconds: 60,
  enableLogging: true,
);
await proxy.connectWithConfig(config);
```

### Connection Management

```dart
// Check connection status
final info = await proxy.getConnectionInfo();
if (info.isConnected) {
  print('Connected to ${info.currentHost}:${info.currentPort}');
  print('Current IP: ${info.currentIp}');
}

// Simple check
final isConnected = await proxy.isConnected();
```

### Statistics

```dart
// Get usage statistics
final stats = await proxy.getStatistics();
print('Total requests: ${stats['totalRequests']}');
print('Success rate: ${stats['successCount']}/${stats['totalRequests']}');

// Reset statistics
await proxy.resetStatistics();
```

## API Reference

### Main Methods

| Method | Description |
|--------|-------------|
| `connect(host, port)` | Connect to SOCKS5 proxy |
| `disconnect()` | Disconnect from proxy |
| `getConnectionInfo()` | Get current connection details |
| `isConnected()` | Check if connected |
| `testConnection()` | Test proxy connection and get IP info |
| `request(url, [options])` | Make HTTP request through proxy |
| `rpcRequest(url, method, [params])` | Make JSON-RPC request |

### ProxyConfig

```dart
ProxyConfig({
  required String host,      // Domain or IP
  required int port,         // Port number
  String? username,          // Optional auth
  String? password,          // Optional auth
  int timeoutSeconds = 30,   // Connection timeout
  bool enableLogging = false,// Debug logging
})
```

### Results

All methods return `ProxyResult`:

```dart
class ProxyResult {
  final bool success;
  final String? message;
  final Map<String, dynamic>? data;
}
```

## Platform Support

| Platform | Status |
|----------|--------|
| Android  | ✅ Supported |
| iOS      | ❌ Not yet |
| Web      | ❌ Not supported |

## Requirements

- Flutter SDK >=2.19.0
- Android minSdkVersion 21
- Internet permission required

## Troubleshooting

### Connection Failed
- Check proxy server is running
- Verify host and port are correct
- Ensure internet permission in AndroidManifest.xml
- Try using domain instead of IP if blocked

### China Specific
- Use domain names instead of IP addresses
- Configure multiple regional servers
- Avoid blocked keywords in domain names

## Example App

See `/example/example.dart` for a complete example with UI.

## License

MIT License