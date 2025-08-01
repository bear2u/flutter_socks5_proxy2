import 'package:flutter/material.dart';
import 'package:flutter_socks5_proxy/flutter_socks5_proxy.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SOCKS5 Proxy Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'SOCKS5 Proxy Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _proxy = Socks5Proxy();
  
  bool _isConnecting = false;
  bool _isConnected = false;
  String _statusMessage = 'Not connected';
  String _connectedIP = '';

  @override
  void initState() {
    super.initState();
    _loadSavedServerInfo();
    _checkConnectionStatus();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedServerInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final savedHost = prefs.getString('socks5_host');
    final savedPort = prefs.getInt('socks5_port');
    
    if (savedHost != null && savedPort != null) {
      setState(() {
        _hostController.text = savedHost;
        _portController.text = savedPort.toString();
      });
    }
  }
  
  Future<void> _saveServerInfo(String host, int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('socks5_host', host);
    await prefs.setInt('socks5_port', port);
  }

  Future<void> _checkConnectionStatus() async {
    final info = await _proxy.getConnectionInfo();
    setState(() {
      _isConnected = info.isConnected;
      if (info.isConnected) {
        _statusMessage = 'Connected to ${info.currentHost}:${info.currentPort}';
      } else {
        _statusMessage = 'Not connected';
      }
    });
  }

  Future<void> _connect() async {
    final host = _hostController.text.trim();
    final portText = _portController.text.trim();
    
    if (host.isEmpty || portText.isEmpty) {
      _showMessage('Please enter host and port');
      return;
    }
    
    final port = int.tryParse(portText);
    if (port == null || port <= 0 || port > 65535) {
      _showMessage('Invalid port number');
      return;
    }
    
    setState(() {
      _isConnecting = true;
      _statusMessage = 'Connecting...';
    });
    
    try {
      final result = await _proxy.connect(host, port);
      
      if (result.success) {
        // 성공적으로 연결되면 서버 정보 저장
        await _saveServerInfo(host, port);
        await _checkConnectionStatus();
        
        // ipify API로 접속한 IP 확인 (프록시를 통해)
        try {
          final response = await _proxy.request('https://api.ipify.org/?format=json');
          print("response => $response");
          if (response['body'] != null) {
            final bodyData = json.decode(response['body']);
            print("data => $bodyData");
            setState(() {
              _connectedIP = "API 호출" + bodyData['ip'] ?? '';
            });
          }
        } catch (e) {
          print('Failed to get IP: $e');
        }
        
        _showMessage('Connected successfully!');
      } else {
        setState(() {
          _statusMessage = result.message ?? 'Connection failed';
          _connectedIP = '';
        });
        _showMessage(result.message ?? 'Connection failed');
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
      _showMessage('Error: $e');
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  Future<void> _disconnect() async {
    setState(() {
      _isConnecting = true;
      _statusMessage = 'Disconnecting...';
    });
    
    try {
      final result = await _proxy.disconnect();
      
      if (result.success) {
        setState(() {
          _isConnected = false;
          _statusMessage = 'Disconnected';
          _connectedIP = '';
        });
        _showMessage('Disconnected successfully');
      } else {
        _showMessage(result.message ?? 'Disconnect failed');
      }
    } catch (e) {
      _showMessage('Error: $e');
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _hostController,
                      decoration: const InputDecoration(
                        labelText: 'Host (Domain or IP)',
                        hintText: 'proxy.example.com or 192.168.1.100',
                        border: OutlineInputBorder(),
                      ),
                      enabled: !_isConnected && !_isConnecting,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _portController,
                      decoration: const InputDecoration(
                        labelText: 'Port',
                        hintText: '1080 or 8388',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      enabled: !_isConnected && !_isConnecting,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Icon(
                          _isConnected ? Icons.check_circle : Icons.cancel,
                          color: _isConnected ? Colors.green : Colors.red,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _statusMessage,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              if (_connectedIP.isNotEmpty)
                                const SizedBox(height: 4),
                              if (_connectedIP.isNotEmpty)
                                Text(
                                  'Connected IP: $_connectedIP',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (_isConnecting || _isConnected) ? null : _connect,
                            icon: const Icon(Icons.link),
                            label: const Text('Connect'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (_isConnecting || !_isConnected) ? null : _disconnect,
                            icon: const Icon(Icons.link_off),
                            label: const Text('Disconnect'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}