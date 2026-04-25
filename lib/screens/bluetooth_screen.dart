import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import '../services/bluetooth_service.dart';

/// Bluetooth Device Connection Screen with Advanced Features
/// Allows user to scan, filter, and connect to smartwatch devices
class BluetoothScreen extends StatefulWidget {
  final BluetoothService bluetoothService;

  const BluetoothScreen({
    Key? key,
    required this.bluetoothService,
  }) : super(key: key);

  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  /// Device discovery map with RSSI values
  final Map<String, Map<String, dynamic>> _discoveredDevices = {};
  
  /// Connection state
  late fbp.BluetoothConnectionState _connectionState;
  fbp.BluetoothDevice? _selectedDevice;
  
  /// UI State
  bool _isScanning = false;
  bool _isConnecting = false;
  String? _statusMessage;
  String? _discoveryLog;

  @override
  void initState() {
    super.initState();
    _connectionState = widget.bluetoothService.connectionState;
    _selectedDevice = widget.bluetoothService.connectedDevice;
    _setupCallbacks();
  }

  /// Setup all Bluetooth callbacks
  void _setupCallbacks() {
    // Device found callback with RSSI
    widget.bluetoothService.onDeviceFound((device, rssi) {
      setState(() {
        final String deviceId = device.id.toString();
        final String name = device.name.isNotEmpty ? device.name : 'Unknown Device';
        final String signal = _getRssiSignal(rssi);

        _discoveredDevices[deviceId] = {
          'device': device,
          'rssi': rssi,
          'signal': signal,
          'timestamp': DateTime.now(),
        };

        // Update discovery log with total count
        String message = 'Found: $name (ID: $deviceId) RSSI: ${rssi} dBm';
        _addLog(message);
        _addLog('Total devices: ${_discoveredDevices.length}');
      });
    });

    // Connection state listener
    widget.bluetoothService.onConnectionState((state) {
      setState(() {
        _connectionState = state;
        _isConnecting = false;
        
        if (state == fbp.BluetoothConnectionState.connected) {
          _statusMessage = '✅ Connected successfully!';
          _selectedDevice = widget.bluetoothService.connectedDevice;
          _addLog('✅ Device connected');
        } else if (state == fbp.BluetoothConnectionState.disconnected) {
          _statusMessage = '❌ Disconnected';
          _selectedDevice = null;
          _addLog('❌ Device disconnected');
        }
      });
    });

    // Services discovered callback
    widget.bluetoothService.onServicesDiscovered((services) {
      setState(() {
        if (services.isEmpty) {
          _addLog('⚠️  No services discovered');
        } else {
          _addLog('✅ Found ${services.length} service(s)');
          for (var service in services) {
            _addLog('   📦 ${service.uuid}');
          }
        }
      });
    });

    // Characteristic discovery callback
    widget.bluetoothService.onCharacteristicFound((serviceUUID, charUUID) {
      // Log in discovery details
    });
  }

  /// Get RSSI signal indicator
  String _getRssiSignal(int rssi) {
    if (rssi >= -50) return '📶 ';      // Excellent
    if (rssi >= -60) return '📶📶 ';    // Very Good
    if (rssi >= -70) return '📶📶📶 ';  // Good
    if (rssi >= -80) return '📶📶📶📶 '; // Fair
    return '📶🔴 ';                      // Poor
  }

  /// Add message to discovery log
  void _addLog(String message) {
    final timestamp = DateTime.now().toString().split('.')[0].split(' ')[1];
    _discoveryLog = '[' + timestamp + '] ' + message + '\n' + (_discoveryLog ?? '');
  }

  /// Start scanning with proper error handling
  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _discoveredDevices.clear();
      _discoveryLog = 'Scan starting...\n';
      _statusMessage = '🔍 Scanning for devices...';
    });

    try {
      // Check Bluetooth is on
      bool bluetoothOn = await widget.bluetoothService.isBluetoothOn();
      if (!bluetoothOn) {
        setState(() {
          _statusMessage = '❌ Bluetooth is off - please enable it in settings';
          _isScanning = false;
          _addLog('❌ Bluetooth disabled');
        });
        return;
      }

      _addLog('Bluetooth is ON');
      _addLog('Starting BLE scan (no filtering)...');

      // Start scan (8s)
      await widget.bluetoothService.startScan(
        timeout: const Duration(seconds: 8),
      );

      setState(() {
        _isScanning = false;
        if (_discoveredDevices.isEmpty) {
          _statusMessage = '⚠️  No devices found - check Bluetooth is enabled on smartwatch';
          _addLog('❌ No devices found');
        } else {
          _statusMessage = 'Found ${_discoveredDevices.length} device(s)';
          _addLog('✅ Scan complete');
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Scan error: $e';
        _isScanning = false;
        _addLog('❌ Scan failed: $e');
      });
    }
  }

  /// Stop scanning
  Future<void> _stopScan() async {
    await widget.bluetoothService.stopScan();
    setState(() {
      _isScanning = false;
      _addLog('Scan stopped');
    });
  }

  /// Connect to device with detailed logging
  Future<void> _connectToDevice(fbp.BluetoothDevice device) async {
    setState(() {
      _isConnecting = true;
      _statusMessage = 'Connecting to ${device.name}...';
      _addLog('🔗 Attempting to connect to ${device.name}...');
    });

    try {
      bool success = await widget.bluetoothService.connectToDevice(device);
      
      if (success) {
        setState(() {
          _statusMessage = '✅ Connected to ${device.name}!';
          _addLog('✅ Connected successfully');
          _addLog('Service discovery in progress...');
        });
      } else {
        setState(() {
          _statusMessage = '❌ Connection failed - try again';
          _addLog('❌ Connection failed');
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Connection error: ${e.toString().substring(0, 50)}...';
        _addLog('❌ Error: $e');
      });
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  /// Disconnect from device
  Future<void> _disconnect() async {
    _addLog('Disconnecting...');
    await widget.bluetoothService.disconnectDevice();
    setState(() {
      _selectedDevice = null;
      _statusMessage = 'Disconnected';
    });
  }

  @override
  void dispose() {
    if (_isScanning) {
      _stopScan();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isConnected = _connectionState == fbp.BluetoothConnectionState.connected;
    final devices = _discoveredDevices.values.toList()
      ..sort((a, b) => (b['rssi'] as int).compareTo(a['rssi'] as int)); // Sort by RSSI

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to Smartwatch'),
        elevation: 0,
        centerTitle: true,
        actions: [
          if (isConnected)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: Chip(
                  label: const Text('Connected'),
                  backgroundColor: Colors.green.shade300,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Connection Status Card
              Card(
                color: isConnected ? Colors.green.shade50 : Colors.grey.shade50,
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                        size: 48,
                        color: isConnected ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isConnected ? '✅ Connected' : '⚪ Not Connected',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isConnected ? Colors.green : Colors.grey,
                        ),
                      ),
                      if (_selectedDevice != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _selectedDevice!.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedDevice!.id.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (_statusMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _statusMessage!,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _statusMessage!.contains('✅')
                                ? Colors.green
                                : _statusMessage!.contains('❌')
                                    ? Colors.red
                                    : Colors.orange,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Disconnect Button (if connected)
              if (isConnected) ...[
                ElevatedButton.icon(
                  onPressed: _disconnect,
                  icon: const Icon(Icons.bluetooth_disabled),
                  label: const Text('Disconnect'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Scan Controls
              if (!isConnected) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isScanning ? _stopScan : _startScan,
                        icon: Icon(_isScanning ? Icons.stop : Icons.search),
                        label: Text(_isScanning ? 'Scanning...' : 'Scan Devices'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Live device count badge
                    Chip(
                      label: Text(
                        '${_discoveredDevices.length}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.blue,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Device List or Empty State
                if (_discoveredDevices.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Icon(
                            _isScanning ? Icons.search : Icons.bluetooth_searching,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isScanning
                                ? 'Scanning for nearby devices...'
                                : 'No devices found yet',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (!_isScanning)
                            Text(
                              'Make sure your smartwatch is:\n'
                              '• Powered on\n'
                              '• Bluetooth is enabled\n'
                              '• Within range (10m)\n\n'
                              'Then tap "Scan Devices"',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  // Device List Header
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Available Devices (${_discoveredDevices.length})',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          'Sorted by signal strength',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Device List
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final deviceData = devices[index];
                      final device = deviceData['device'] as fbp.BluetoothDevice;
                      final rssi = deviceData['rssi'] as int;
                      final signal = deviceData['signal'] as String;

                      return DeviceListTile(
                        device: device,
                        rssi: rssi,
                        signal: signal,
                        onTap: () => _connectToDevice(device),
                        isConnecting: _isConnecting,
                      );
                    },
                  ),
                ],
              ],

              // Discovery Log (collapsible)
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              _buildDiscoveryLogSection(),
            ],
          ),
        ),
      ),
    );
  }

  /// Build collapsible discovery log section
  Widget _buildDiscoveryLogSection() {
    return ExpansionTile(
      title: const Text(
        'Discovery Log',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
      subtitle: _discoveryLog != null ? Text(_discoveryLog!.split('\n')[0]) : null,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: SingleChildScrollView(
            child: Text(
              _discoveryLog ?? 'No log',
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'Courier',
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Enhanced Device List Tile with RSSI Display
class DeviceListTile extends StatelessWidget {
  final fbp.BluetoothDevice device;
  final int rssi;
  final String signal;
  final VoidCallback onTap;
  final bool isConnecting;

  const DeviceListTile({
    Key? key,
    required this.device,
    required this.rssi,
    required this.signal,
    required this.onTap,
    required this.isConnecting,
  }) : super(key: key);

  /// Get RSSI quality color
  Color _getRssiColor(int rssi) {
    if (rssi >= -50) return Colors.green;
    if (rssi >= -60) return Colors.lightGreen;
    if (rssi >= -70) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Tooltip(
          message: 'Signal strength',
          child: Text(
            signal,
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            device.name.isEmpty ? 'Unknown Device' : device.name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ID: ${device.id.toString()}',
              style: const TextStyle(fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getRssiColor(rssi),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'RSSI: $rssi dBm',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: isConnecting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              )
            : Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
        onTap: isConnecting ? null : onTap,
        enabled: !isConnecting,
      ),
    );
  }
}
