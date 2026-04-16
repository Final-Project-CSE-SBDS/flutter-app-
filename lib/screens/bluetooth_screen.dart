import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import '../services/bluetooth_service.dart';

/// Bluetooth Device Connection Screen
/// Allows user to scan for and connect to smartwatch devices
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
  /// Discovered devices
  final Map<String, fbp.BluetoothDevice> _discoveredDevices = {};
  
  /// Connection status
  late fbp.BluetoothConnectionState _connectionState;
  
  /// Selected device
  fbp.BluetoothDevice? _selectedDevice;
  
  /// UI State
  bool _isScanning = false;
  bool _isConnecting = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _connectionState = widget.bluetoothService.connectionState;
    _selectedDevice = widget.bluetoothService.connectedDevice;
    _setupCallbacks();
  }

  /// Setup Bluetooth callbacks
  void _setupCallbacks() {
    widget.bluetoothService.onDeviceFound((device) {
      setState(() {
        if (device.name.isNotEmpty) {
          _discoveredDevices[device.id.toString()] = device;
        }
      });
    });

    widget.bluetoothService.onConnectionState((state) {
      setState(() {
        _connectionState = state;
        _isConnecting = false;
        
        if (state == fbp.BluetoothConnectionState.connected) {
          _statusMessage = '✅ Connected!';
          _selectedDevice = widget.bluetoothService.connectedDevice;
        } else if (state == fbp.BluetoothConnectionState.disconnected) {
          _statusMessage = 'Disconnected';
          _selectedDevice = null;
        }
      });
    });
  }

  /// Start scanning for devices
  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _discoveredDevices.clear();
      _statusMessage = 'Scanning for devices...';
    });

    try {
      bool bluetoothOn = await widget.bluetoothService.isBluetoothOn();
      if (!bluetoothOn) {
        setState(() {
          _statusMessage = '❌ Bluetooth is off. Please enable it.';
          _isScanning = false;
        });
        return;
      }

      await widget.bluetoothService.startScan(
        timeout: const Duration(seconds: 10),
      );

      setState(() {
        _isScanning = false;
        if (_discoveredDevices.isEmpty) {
          _statusMessage = '⚠️ No devices found';
        } else {
          _statusMessage = 'Found ${_discoveredDevices.length} device(s)';
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Scan failed: $e';
        _isScanning = false;
      });
    }
  }

  /// Stop scanning
  Future<void> _stopScan() async {
    await widget.bluetoothService.stopScan();
    setState(() {
      _isScanning = false;
    });
  }

  /// Connect to selected device
  Future<void> _connectToDevice(fbp.BluetoothDevice device) async {
    setState(() {
      _isConnecting = true;
      _statusMessage = 'Connecting to ${device.name}...';
      _selectedDevice = device;
    });

    try {
      bool success = await widget.bluetoothService.connectToDevice(device);
      
      if (success) {
        setState(() {
          _statusMessage = '✅ Connected to ${device.name}';
        });
      } else {
        setState(() {
          _statusMessage = '❌ Connection failed';
          _selectedDevice = null;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Error: $e';
        _selectedDevice = null;
      });
    }
  }

  /// Disconnect from current device
  Future<void> _disconnect() async {
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to Smartwatch'),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Connection Status Card
              Card(
                color: isConnected
                    ? Colors.green.shade50
                    : Colors.grey.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                        size: 40,
                        color: isConnected ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isConnected ? 'Connected' : 'Not Connected',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isConnected ? Colors.green : Colors.grey,
                        ),
                      ),
                      if (_selectedDevice != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Device: ${_selectedDevice!.name}',
                          style: const TextStyle(fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (_statusMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _statusMessage!,
                          style: TextStyle(
                            fontSize: 12,
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
              if (isConnected)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ElevatedButton.icon(
                    onPressed: _disconnect,
                    icon: const Icon(Icons.bluetooth_disabled),
                    label: const Text('Disconnect'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

              // Scan Controls
              if (!isConnected) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isScanning ? _stopScan : _startScan,
                        icon: Icon(
                          _isScanning ? Icons.stop : Icons.search,
                        ),
                        label: Text(_isScanning ? 'Scanning...' : 'Scan Devices'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Device List
                if (_discoveredDevices.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        _isScanning
                            ? 'Scanning for devices...'
                            : 'No devices found\nTap "Scan Devices" to search',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Devices (${_discoveredDevices.length})',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _discoveredDevices.length,
                        itemBuilder: (context, index) {
                          final device = _discoveredDevices.values.toList()[index];
                          return DeviceListTile(
                            device: device,
                            onTap: () => _connectToDevice(device),
                            isConnecting: _isConnecting,
                          );
                        },
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Device List Tile Widget
class DeviceListTile extends StatelessWidget {
  final fbp.BluetoothDevice device;
  final VoidCallback onTap;
  final bool isConnecting;

  const DeviceListTile({
    Key? key,
    required this.device,
    required this.onTap,
    required this.isConnecting,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(
          Icons.watch,
          color: Colors.blue,
        ),
        title: Text(
          device.name.isEmpty ? 'Unknown Device' : device.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          device.id.toString(),
          style: const TextStyle(fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isConnecting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: isConnecting ? null : onTap,
      ),
    );
  }
}
