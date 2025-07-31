import 'dart:async';
import 'package:flutter/services.dart';
import 'proxy_config.dart';
import 'proxy_result.dart';

/// Simple SOCKS5 proxy client for Flutter
/// 
/// Usage:
/// ```dart
/// final proxy = Socks5Proxy();
/// 
/// // Connect to proxy
/// await proxy.connect('proxy.example.com', 8388);
/// 
/// // Check connection
/// final info = await proxy.getConnectionInfo();
/// print('Connected: ${info.isConnected}');
/// 
/// // Make HTTP requests (they will go through proxy)
/// final response = await proxy.request('https://api.example.com/data');
/// 
/// // Disconnect
/// await proxy.disconnect();
/// ```
class Socks5Proxy {
  static const MethodChannel _channel = MethodChannel('flutter_socks5_proxy');
  
  static Socks5Proxy? _instance;
  ProxyConfig? _currentConfig;
  
  /// Get singleton instance
  factory Socks5Proxy() {
    _instance ??= Socks5Proxy._internal();
    return _instance!;
  }
  
  Socks5Proxy._internal();

  /// Connect to SOCKS5 proxy server
  /// 
  /// [host] can be either domain name or IP address
  /// [port] is the proxy server port (commonly 1080 or 8388)
  Future<ProxyResult> connect(String host, int port, {
    String? username,
    String? password,
    bool enableLogging = false,
  }) async {
    try {
      final config = ProxyConfig(
        host: host,
        port: port,
        username: username,
        password: password,
        enableLogging: enableLogging,
      );
      
      return connectWithConfig(config);
    } catch (e) {
      return ProxyResult.failure('Connection failed: $e');
    }
  }

  /// Connect using ProxyConfig object
  Future<ProxyResult> connectWithConfig(ProxyConfig config) async {
    try {
      final result = await _channel.invokeMethod<Map>('connect', config.toMap());
      
      if (result?['success'] == true) {
        _currentConfig = config;
        return ProxyResult.success(
          'Connected to ${config.host}:${config.port}',
          result?.cast<String, dynamic>(),
        );
      } else {
        return ProxyResult.failure(
          result?['error'] ?? 'Connection failed',
        );
      }
    } on PlatformException catch (e) {
      return ProxyResult.failure('Platform error: ${e.message}');
    } catch (e) {
      return ProxyResult.failure('Unexpected error: $e');
    }
  }

  /// Disconnect from proxy
  Future<ProxyResult> disconnect() async {
    try {
      final result = await _channel.invokeMethod<Map>('disconnect');
      
      if (result?['success'] == true) {
        _currentConfig = null;
        return ProxyResult.success('Disconnected');
      } else {
        return ProxyResult.failure(
          result?['error'] ?? 'Disconnect failed',
        );
      }
    } on PlatformException catch (e) {
      return ProxyResult.failure('Platform error: ${e.message}');
    } catch (e) {
      return ProxyResult.failure('Unexpected error: $e');
    }
  }

  /// Get current connection information
  Future<ConnectionInfo> getConnectionInfo() async {
    try {
      final result = await _channel.invokeMethod<Map>('getConnectionInfo');
      
      if (result == null || result['isConnected'] != true) {
        return ConnectionInfo.disconnected();
      }
      
      return ConnectionInfo.connected(
        host: result['host'] ?? _currentConfig?.host ?? '',
        port: result['port'] ?? _currentConfig?.port ?? 0,
        ip: result['ip'],
        location: result['location'],
      );
    } catch (e) {
      return ConnectionInfo.disconnected();
    }
  }

  /// Check if proxy is connected
  Future<bool> isConnected() async {
    final info = await getConnectionInfo();
    return info.isConnected;
  }

  /// Test proxy connection
  Future<ProxyResult> testConnection() async {
    try {
      final result = await _channel.invokeMethod<Map>('testConnection');
      
      if (result?['success'] == true) {
        final ip = result?['ip'] ?? 'Unknown';
        final location = result?['location'] ?? 'Unknown';
        return ProxyResult.success(
          'Connected via proxy. IP: $ip, Location: $location',
          result?.cast<String, dynamic>(),
        );
      } else {
        return ProxyResult.failure(
          result?['error'] ?? 'Connection test failed',
        );
      }
    } catch (e) {
      return ProxyResult.failure('Test failed: $e');
    }
  }

  /// Make HTTP request through proxy
  Future<Map<String, dynamic>> request(String url, {
    String method = 'GET',
    Map<String, String>? headers,
    dynamic body,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map>('request', {
        'url': url,
        'method': method,
        'headers': headers,
        'body': body,
      });
      
      return result?.cast<String, dynamic>() ?? {};
    } on PlatformException catch (e) {
      throw Exception('Request failed: ${e.message}');
    }
  }

  /// Make RPC request through proxy
  Future<Map<String, dynamic>> rpcRequest(
    String url,
    String method, {
    List<dynamic> params = const [],
    int id = 1,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map>('rpcRequest', {
        'url': url,
        'method': method,
        'params': params,
        'id': id,
      });
      
      return result?.cast<String, dynamic>() ?? {};
    } on PlatformException catch (e) {
      throw Exception('RPC request failed: ${e.message}');
    }
  }

  /// Get proxy statistics
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final result = await _channel.invokeMethod<Map>('getStatistics');
      return result?.cast<String, dynamic>() ?? {};
    } catch (e) {
      return {
        'error': 'Failed to get statistics: $e',
      };
    }
  }

  /// Reset proxy statistics
  Future<void> resetStatistics() async {
    await _channel.invokeMethod('resetStatistics');
  }

  /// Get current proxy configuration
  ProxyConfig? get currentConfig => _currentConfig;
}

/// Extension for easy blockchain RPC
extension BlockchainRPC on Socks5Proxy {
  /// Get latest block number
  Future<String> getBlockNumber(String rpcUrl) async {
    final result = await rpcRequest(rpcUrl, 'eth_blockNumber');
    return result['result'] ?? '';
  }

  /// Get account balance
  Future<String> getBalance(String rpcUrl, String address) async {
    final result = await rpcRequest(
      rpcUrl,
      'eth_getBalance',
      params: [address, 'latest'],
    );
    return result['result'] ?? '0x0';
  }

  /// Get gas price
  Future<String> getGasPrice(String rpcUrl) async {
    final result = await rpcRequest(rpcUrl, 'eth_gasPrice');
    return result['result'] ?? '';
  }
}