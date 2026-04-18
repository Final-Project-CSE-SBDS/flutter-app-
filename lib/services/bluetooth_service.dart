import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;

/// Callbacks for Bluetooth events
typedef OnDeviceFound = void Function(fbp.BluetoothDevice device, int rssi);
typedef OnConnectionState = void Function(fbp.BluetoothConnectionState state);
typedef OnDataReceived = void Function(String data);
typedef OnServicesDiscovered = void Function(List<fbp.BluetoothService> services);
typedef OnCharacteristicFound = void Function(String serviceUUID, String characteristicUUID);

/// Service for Bluetooth Low Energy (BLE) communication
/// Handles scanning, connection, service discovery, and data transmission
/// with comprehensive error handling and debugging
class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();

  BluetoothService._internal();

  factory BluetoothService() {
    return _instance;
  }

  // ============= Device State =============
  fbp.BluetoothDevice? _connectedDevice;
  bool _isScanning = false;
  fbp.BluetoothConnectionState _connectionState =
      fbp.BluetoothConnectionState.disconnected;

  // ============= Services & Characteristics =============
  List<fbp.BluetoothService> _services = [];
  fbp.BluetoothCharacteristic? _writeCharacteristic;
  fbp.BluetoothCharacteristic? _notifyCharacteristic;
  final Map<String, fbp.BluetoothCharacteristic> _characteristicMap = {};

  // ============= Callbacks =============
  OnDeviceFound? _onDeviceFound;
  OnConnectionState? _onConnectionState;
  OnDataReceived? _onDataReceived;
  OnServicesDiscovered? _onServicesDiscovered;
  OnCharacteristicFound? _onCharacteristicFound;

  // ============= Stream Subscriptions =============
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _notifySubscription;
  final List<StreamSubscription> _activeSubscriptions = [];

  // ============= Configuration =============
  /// RSSI threshold for filtering weak signals (in dBm)
  static const int rssiThreshold = -90;
  
  /// Timeout durations
  static const Duration scanTimeout = Duration(seconds: 10);
  static const Duration connectionTimeout = Duration(seconds: 15);
  static const Duration discoveryTimeout = Duration(seconds: 5);

  // ============= Standard GATT UUIDs =============
  static const String genericAccessServiceUUID = '00001800-0000-1000-8000-00805f9b34fb';
  static const String deviceInfoServiceUUID = '0000180a-0000-1000-8000-00805f9b34fb';
  static const String batteryServiceUUID = '0000180f-0000-1000-8000-00805f9b34fb';
  
  // ============= Common Custom Service UUIDs =============
  /// Nordic UART Service (common for smartwatches)
  static const String nordicUartServiceUUID = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  static const String nordicTxCharacteristicUUID = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';
  static const String nordicRxCharacteristicUUID = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';

  
  // ============= Getters =============
  bool get isConnected => _connectionState == fbp.BluetoothConnectionState.connected;
  bool get isScanning => _isScanning;
  fbp.BluetoothDevice? get connectedDevice => _connectedDevice;
  fbp.BluetoothConnectionState get connectionState => _connectionState;
  bool get hasWriteCharacteristic => _writeCharacteristic != null;
  List<fbp.BluetoothService> get services => _services;
  Map<String, fbp.BluetoothCharacteristic> get characteristics => _characteristicMap;

  // ============= Callback Registration =============
  void onDeviceFound(OnDeviceFound callback) => _onDeviceFound = callback;
  void onConnectionState(OnConnectionState callback) => _onConnectionState = callback;
  void onDataReceived(OnDataReceived callback) => _onDataReceived = callback;
  void onServicesDiscovered(OnServicesDiscovered callback) => _onServicesDiscovered = callback;
  void onCharacteristicFound(OnCharacteristicFound callback) => _onCharacteristicFound = callback;

  // ============= Bluetooth Initialization =============
  /// Check if Bluetooth is supported
  Future<bool> checkBluetoothAvailable() async {
    try {
      bool isSupported = await fbp.FlutterBluePlus.isSupported;
      _log('✓ Bluetooth supported: $isSupported');
      return isSupported;
    } catch (e) {
      _logError('Error checking Bluetooth: $e');
      return false;
    }
  }

  /// Check if Bluetooth is enabled
  Future<bool> isBluetoothOn() async {
    try {
      bool isOn = await fbp.FlutterBluePlus.adapterState.first ==
          fbp.BluetoothAdapterState.on;
      _log('Bluetooth is ${isOn ? 'ON' : 'OFF'}');
      return isOn;
    } catch (e) {
      _logError('Error checking Bluetooth state: $e');
      return false;
    }
  }

  // ============= Scanning Methods =============
  /// Start scanning for BLE devices with filters
  /// Shows all discoverable devices
  Future<void> startScan({Duration timeout = scanTimeout}) async {
    try {
      // Check Bluetooth availability first
      bool isAvailable = await checkBluetoothAvailable();
      if (!isAvailable) {
        _logError('Bluetooth not available on this device');
        return;
      }

      bool isOn = await isBluetoothOn();
      if (!isOn) {
        _logError('Bluetooth is turned off - please enable Bluetooth');
        return;
      }

      if (_isScanning) {
        _logWarn('Scan already in progress');
        return;
      }

      _log('🔍 Starting BLE scan...');
      _isScanning = true;

      // Cancel previous subscription
      await _scanSubscription?.cancel();

      // Listen to scan results
      _scanSubscription = fbp.FlutterBluePlus.scanResults.listen(
        (results) {
          for (fbp.ScanResult result in results) {
            final device = result.device;
            final rssi = result.rssi;
            final name = device.name.isEmpty ? '(Unknown)' : device.name;

            // Print ALL devices found (no RSSI filtering)
            _log('📱 Found device: $name (ID: ${device.id}, RSSI: $rssi dBm)');
            _onDeviceFound?.call(device, rssi);
          }
        },
        onError: (error) {
          _logError('Scan error: $error');
        },
      );

      // Start actual scan
      await fbp.FlutterBluePlus.startScan(
        timeout: timeout,
      );

      // Auto-stop after timeout
      Future.delayed(timeout, () {
        if (_isScanning) {
          stopScan();
        }
      });
    } catch (e) {
      _logError('Failed to start scan: $e');
      _isScanning = false;
      rethrow;
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    try {
      if (!_isScanning) return;

      await fbp.FlutterBluePlus.stopScan();
      _isScanning = false;
      _log('⏹️  Scan stopped');
    } catch (e) {
      _logError('Error stopping scan: $e');
    }
  }

  // ============= Connection Methods =============
  /// Connect to a specific device
  Future<bool> connectToDevice(fbp.BluetoothDevice device, {bool autoConnect = false}) async {
    try {
      _log('🔗 Connecting to ${device.name} (${device.id})...');
      _log('   Device state: ${device.connectionState}');

      // Disconnect from current device first if different
      if (_connectedDevice != null && _connectedDevice!.id != device.id) {
        _log('   Disconnecting from previous device first...');
        await disconnectDevice();
      }

      // Establish connection
      _log('   Sending connection request...');
      await device.connect(
        autoConnect: autoConnect,
        timeout: connectionTimeout,
      );

      _connectedDevice = device;
      _log('✅ Connected to ${device.name}');

      // Listen to connection state changes
      await _setupConnectionStateListener();

      // Discover services after connection
      await _discoverServices();

      return true;
    } catch (e) {
      _logError('Connection failed: $e');
      _connectedDevice = null;
      return false;
    }
  }

  /// Setup connection state listener
  Future<void> _setupConnectionStateListener() async {
    try {
      if (_connectedDevice == null) return;

      // Cancel previous subscription
      await _connectionSubscription?.cancel();

      _connectionSubscription = _connectedDevice!.connectionState.listen(
        (state) async {
          _log('📡 Connection state: $state');
          _connectionState = state;
          _onConnectionState?.call(state);

          if (state == fbp.BluetoothConnectionState.disconnected) {
            _log('❌ Device disconnected');
            await _cleanup();
          }
        },
        onError: (error) {
          _logError('Connection listener error: $error');
        },
      );
    } catch (e) {
      _logError('Failed to setup connection listener: $e');
    }
  }

  /// Disconnect from current device
  Future<void> disconnectDevice() async {
    try {
      if (_connectedDevice != null) {
        _log('Disconnecting from ${_connectedDevice!.name}...');
        await _connectedDevice!.disconnect();
        await _cleanup();
        _log('✓ Disconnected');
      }
    } catch (e) {
      _logError('Disconnect error: $e');
    }
  }

  /// Cleanup resources
  Future<void> _cleanup() async {
    _connectedDevice = null;
    _connectionState = fbp.BluetoothConnectionState.disconnected;
    _services = [];
    _writeCharacteristic = null;
    _notifyCharacteristic = null;
    _characteristicMap.clear();

    await _notifySubscription?.cancel();
    for (var sub in _activeSubscriptions) {
      await sub.cancel();
    }
    _activeSubscriptions.clear();
  }

  // ============= Service Discovery =============
  /// Discover all GATT services and characteristics
  Future<void> _discoverServices() async {
    try {
      if (_connectedDevice == null) {
        _logError('No device connected');
        return;
      }

      _log('🔎 Discovering GATT services and characteristics...');

      List<fbp.BluetoothService> services =
          await _connectedDevice!.discoverServices();

      if (services.isEmpty) {
        _logWarn('No services discovered');
        _onServicesDiscovered?.call([]);
        return;
      }

      _services = services;
      _log('✅ Discovered ${services.length} service(s)');

      // Iterate through all services and characteristics
      for (var service in services) {
        final serviceUUID = service.uuid.toString().toLowerCase();
        _log('');
        _log('╔═══════════════════════════════════════════════════════════');
        _log('║ Service: $serviceUUID');
        _log('║ Characteristics: ${service.characteristics.length}');
        _log('╚═══════════════════════════════════════════════════════════');

        int charIndex = 0;
        for (var characteristic in service.characteristics) {
          charIndex++;
          final charUUID = characteristic.uuid.toString().toLowerCase();

          _characteristicMap[charUUID] = characteristic;

          _log('  [$charIndex] UUID: $charUUID');
          _log('      Properties: ${_formatProperties(characteristic.properties)}');
          _log('      Read: ${characteristic.properties.read}');
          _log('      Write: ${characteristic.properties.write}');
          _log('      WriteNoResp: ${characteristic.properties.writeWithoutResponse}');
          _log('      Notify: ${characteristic.properties.notify}');
          _log('      Indicate: ${characteristic.properties.indicate}');

          // Store writable characteristics
          if (characteristic.properties.write ||
              characteristic.properties.writeWithoutResponse) {
            if (_writeCharacteristic == null) {
              _writeCharacteristic = characteristic;
              _log('      ✓ [WRITABLE] Stored as primary write characteristic');
            } else {
              _log('      ✓ [WRITABLE] Alternative write characteristic available');
            }
          }

          // Store notify/indicate characteristics for reading data
          if (characteristic.properties.notify ||
              characteristic.properties.indicate) {
            if (_notifyCharacteristic == null) {
              _notifyCharacteristic = characteristic;
              _log('      ✓ [NOTIFIABLE] Stored as primary notify characteristic');
            } else {
              _log('      ✓ [NOTIFIABLE] Alternative notify characteristic available');
            }
          }

          _onCharacteristicFound?.call(serviceUUID, charUUID);
        }
      }

      _log('');
      if (_writeCharacteristic != null) {
        _log('✅ Found writable characteristic: ${_writeCharacteristic!.uuid}');
        _log('   Can send data: ${_writeCharacteristic!.properties.write ? 'YES (with response)' : 'YES (without response)'}');
      } else {
        _logWarn('❌ No writable characteristic found - sending will fail!');
      }

      if (_notifyCharacteristic != null) {
        _log('✅ Found notify characteristic: ${_notifyCharacteristic!.uuid}');
        await _enableNotifications(_notifyCharacteristic!);
      }

      _onServicesDiscovered?.call(_services);
    } catch (e) {
      _logError('Service discovery error: $e');
      _onServicesDiscovered?.call([]);
    }
  }

  /// Enable notifications on a characteristic
  Future<void> _enableNotifications(fbp.BluetoothCharacteristic characteristic) async {
    try {
      if (!characteristic.properties.notify && !characteristic.properties.indicate) {
        _logWarn('Characteristic does not support notify/indicate');
        return;
      }

      _log('Setting up notifications for ${characteristic.uuid}...');
      
      // Set notify value
      await characteristic.setNotifyValue(true);

      // Listen to value changes
      await _notifySubscription?.cancel();
      _notifySubscription = characteristic.onValueReceived.listen(
        (value) {
          try {
            String receivedData = utf8.decode(value);
            _log('📥 Data received: $receivedData');
            _onDataReceived?.call(receivedData);
          } catch (e) {
            _logError('Failed to decode received data: $e');
          }
        },
        onError: (error) {
          _logError('Notification listener error: $error');
        },
      );

      _log('✓ Notifications enabled for ${characteristic.uuid}');
    } catch (e) {
      _logError('Error enabling notifications: $e');
    }
  }

  // ============= Data Transmission =============
  /// Send ECG prediction result to connected device
  Future<bool> sendPredictionResult({
    required String label,
    required double confidence,
    bool includeConfidence = false, // Changed to false
  }) async {
    String message = includeConfidence
        ? '$label:${confidence.toStringAsFixed(1)}%'
        : label;

    return sendData(message);
  }

  /// Send raw data to connected device
  /// Returns true if send was successful
  Future<bool> sendData(String data) async {
    try {
      if (!isConnected || _connectedDevice == null) {
        _logWarn('Not connected to device - cannot send data');
        return false;
      }

      if (_writeCharacteristic == null) {
        _logError('❌ No writable characteristic available - cannot send data!');
        _log('💡 Possible solutions:');
        _log('   1. Ensure the smartwatch is properly connected');
        _log('   2. Check that the device supports BLE write operations');
        _log('   3. Try reconnecting to the device');
        _log('   4. Check service discovery logs above for writable characteristics');
        return false;
      }

      List<int> bytes = utf8.encode(data);
      _log('📤 Sending: "$data" (${bytes.length} bytes)');
      _log('   Using characteristic: ${_writeCharacteristic!.uuid}');
      _log('   Write with response: ${_writeCharacteristic!.properties.write}');
      _log('   Write without response: ${_writeCharacteristic!.properties.writeWithoutResponse}');

      // Send with appropriate method based on characteristics
      if (_writeCharacteristic!.properties.write) {
        // Write with response
        _log('   Sending with response...');
        await _writeCharacteristic!.write(bytes, withoutResponse: false);
        _log('✅ Data sent (with response)');
      } else if (_writeCharacteristic!.properties.writeWithoutResponse) {
        // Write without response (faster)
        _log('   Sending without response...');
        await _writeCharacteristic!.write(bytes, withoutResponse: true);
        _log('✅ Data sent (without response)');
      } else {
        _logError('Write characteristic has no write modes enabled');
        return false;
      }

      return true;
    } catch (e) {
      _logError('Failed to send data: $e');
      return false;
    }
  }

  // ============= Utility Methods =============
  /// Format characteristic properties for logging
  String _formatProperties(fbp.CharacteristicProperties props) {
    List<String> features = [];
    if (props.read) features.add('READ');
    if (props.write) features.add('WRITE');
    if (props.writeWithoutResponse) features.add('WRITE_NO_RESP');
    if (props.notify) features.add('NOTIFY');
    if (props.indicate) features.add('INDICATE');
    if (props.authenticatedSignedWrites) features.add('AUTH_SIGNED_WRITE');
    if (props.extendedProperties) features.add('EXTENDED');
    return features.isEmpty ? '[NONE]' : '[${features.join(', ')}]';
  }

  /// Logging helper
  void _log(String message) {
    print('🔵 BLE: $message');
  }

  void _logWarn(String message) {
    print('🟡 BLE: $message');
  }

  void _logError(String message) {
    print('🔴 BLE: $message');
  }

  // ============= Cleanup =============
  /// Dispose all subscriptions and resources
  Future<void> dispose() async {
    try {
      _log('Disposing BluetoothService...');
      if (_isScanning) {
        await stopScan();
      }
      await disconnectDevice();
      await _scanSubscription?.cancel();
      await _connectionSubscription?.cancel();
      await _notifySubscription?.cancel();
      for (var sub in _activeSubscriptions) {
        await sub.cancel();
      }
      _log('✓ Cleanup complete');
    } catch (e) {
      _logError('Dispose error: $e');
    }
  }
}
