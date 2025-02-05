import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Printer App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const InputPage(),
    );
  }
}

class InputPage extends StatefulWidget {
  const InputPage({super.key});

  @override
  State<InputPage> createState() => _InputPageState();
}

class _InputPageState extends State<InputPage> {
  final TextEditingController _circuitIdController = TextEditingController();
  final TextEditingController _posIdsController = TextEditingController();
  IO.Socket? _socket;
  WebViewController? _webViewController;
  bool _isConnected = false;
  String _currentSubscription = '';
  String _printerStatus = 'Ready';

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (WebResourceError error) {
            debugPrint('Web resource error: ${error.description}');
          },
        ),
      )
      ..loadFlutterAsset('assets/index.html');

    _webViewController = controller;
  }

  void _disconnectSocket() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      setState(() {
        _isConnected = false;
        _currentSubscription = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Disconnected from server')),
      );
    }
  }

  Future<void> _triggerPrint() async {
    setState(() => _printerStatus = 'Sending print request...');
    try {
      await _webViewController?.runJavaScript('triggerPrint()');
      setState(() => _printerStatus = 'Print request sent successfully');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.print, color: Colors.white),
                SizedBox(width: 8),
                Text('Print command sent successfully'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      setState(() => _printerStatus = 'Error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Flexible(child: Text('Error: $error')),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // Reset status after 3 seconds
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      setState(() => _printerStatus = 'Ready');
    }
  }

  void _connectSocket() {
    final circuitId = _circuitIdController.text;
    final posIds =
        _posIdsController.text.split(',').map((e) => e.trim()).toList();

    if (circuitId.isEmpty || posIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    _socket = IO.io(
        'ws://fp-socket.exagonplus.com',
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .build());

    _socket!.onConnect((_) {
      debugPrint('Socket connected');
      setState(() {
        _isConnected = true;
        _currentSubscription =
            'Circuit ID: $circuitId\nPOS IDs: ${posIds.join(", ")}';
      });

      // Emit register event
      _socket!.emit('register', {
        'circuitId': circuitId,
        'posIds': posIds,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connected and registered successfully')),
      );
    });

    _socket!.on('raise-printer', (_) async {
      debugPrint('Printer raised at: ${DateTime.now()}');
      await _triggerPrint();
    });

    _socket!.onDisconnect((_) {
      debugPrint('Socket disconnected');
      setState(() => _isConnected = false);
    });

    _socket!.onError((error) {
      debugPrint('Socket error: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Socket error: $error')),
      );
      setState(() => _isConnected = false);
    });

    _socket!.connect();
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _circuitIdController.dispose();
    _posIdsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Setup'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Stack(
        children: [
          // WebView nascosta
          Opacity(
            opacity: 0,
            child: SizedBox(
              height: 1,
              width: 1,
              child: WebViewWidget(controller: _webViewController!),
            ),
          ),
          // UI principale
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Connection Setup',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        if (_isConnected)
                          TextButton.icon(
                            onPressed: _disconnectSocket,
                            icon: const Icon(Icons.logout, color: Colors.red),
                            label: const Text(
                              'Disconnect',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                    if (_currentSubscription.isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green[100]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Current Subscription:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentSubscription,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: _circuitIdController,
                      enabled: !_isConnected,
                      decoration: InputDecoration(
                        labelText: 'Circuit ID',
                        hintText: 'Enter numeric Circuit ID',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor:
                            _isConnected ? Colors.grey[100] : Colors.grey[50],
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _posIdsController,
                      enabled: !_isConnected,
                      decoration: InputDecoration(
                        labelText: 'POS IDs',
                        hintText:
                            'Enter numeric POS IDs separated by commas (e.g., 1,2,3)',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor:
                            _isConnected ? Colors.grey[100] : Colors.grey[50],
                      ),
                      keyboardType: TextInputType.text,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isConnected ? null : _connectSocket,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: _isConnected
                            ? Colors.green[100]
                            : Theme.of(context).primaryColor,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isConnected
                                ? Icons.check_circle
                                : Icons.power_settings_new,
                            color: _isConnected ? Colors.green : Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isConnected ? 'Connected' : 'Connect',
                            style: TextStyle(
                              color: _isConnected ? Colors.green : Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Printer Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _printerStatus,
                        style: TextStyle(
                          fontSize: 16,
                          color: _printerStatus.contains('Error')
                              ? Colors.red
                              : _printerStatus.contains('Success')
                                  ? Colors.green
                                  : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _triggerPrint,
                        icon: const Icon(Icons.print),
                        label: const Text('Test Print'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ],
      ),
    );
  }
}
