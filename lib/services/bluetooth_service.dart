import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;

/// Callbacks for Bluetooth events
typedef OnDeviceFound = void Function(fbp.BluetoothDevice device);
typedef OnConnectionState = void Function(fbp.BluetoothConnectionState state);
typedef OnDataReceived = void Function(String data);
typedef OnServicesDiscovered = void Function();

/// Service for Bluetooth communication with wearable devices
/// Handles real BLE scanning, connecting, discovering services, and sending data
class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();

  BluetoothService._internal();

  factory BluetoothService() {
    return _instance;
  }

  /// Connected device
  fbp.BluetoothDevice? _connectedDevice;

  /// Scanning state
  bool _isScanning = false;

  /// Connection state
  fbp.BluetoothConnectionState _connectionState =
      fbp.BluetoothConnectionState.disconnected;

  /// Discovered services and characteristics
  List<fbp.BluetoothService> _services = [];
  fbp.BluetoothCharacteristic? _writeCharacteristic;

  /// Callbacks
  OnDeviceFound? _onDeviceFound;
  OnConnectionState? _onConnectionState;
  OnDataReceived? _onDataReceived;
  OnServicesDiscovered? _onServicesDiscovered;

  /// Stream subscriptions
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;

  /// Service UUIDs (standard GATT services)
  /// Using standard GATT UUIDs for broader smartwatch compatibility
  static const String genericAccessServiceUUID = '00001800-0000-1000-8000-00805f9b34fb';
  static const String deviceInfoServiceUUID = '0000180a-0000-1000-8000-00805f9b34fb';
  static const String genericAttributeServiceUUID = '00001801-0000-1000-8000-00805f9b34fb';
  
  /// Custom service UUID (can be configured for specific smartwatches)
  static const String customServiceUUID = '0000ffe0-0000-1000-8000-00805f9b34fb';
  static const String customCharacteristicUUID = '0000ffe1-0000-1000-8000-00805f9b34fb';

  /// Getters
  bool get isConnected => _connectionState == fbp.BluetoothConnectionState.connected;
  bool get isScanning => _isScanning;
  fbp.BluetoothDevice? get connectedDevice => _connectedDevice;
  fbp.BluetoothConnectionState get connectionState => _connectionState;
  bool get hasWriteCharacteristic => _writeCharacteristic != null;
  List<fbp.BluetoothService> get services => _services;

  /// Register callbacks
  void onDeviceFound(OnDeviceFound callback) => _onDeviceFound = callback;
  void onConnectionState(OnConnectionState callback) =>
      _onConnectionState = callback;
  void onDataReceived(OnDataReceived callback) => _onDataReceived = callback;
  void onServicesDiscovered(OnServicesDiscovered callback) =>
      _onServicesDiscovered = callback;

  /// Check Bluetooth availability
  Future<bool> checkBluetoothAvailable() async {
    try {
      bool isSupported = await fbp.FlutterBluePlus.isSupported;
      print('✓ Bluetooth supported: $isSupported');
      return isSupported;
    } catch (e) {
      print('❌ Error checking Bluetooth: $e');
      return false;
    }
  }

  /// Check if Bluetooth is enabled
  Future<bool> isBluetoothOn() async {
    try {
      return await fbp.FlutterBluePlus.adapterState.first ==
          fbp.BluetoothAdapterState.on;
    } catch (e) {
      print('❌ Error checking Bluetooth state: $e');
      return false;
    }
  }

  /// Start scanning for devices
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    try {
      if (_isScanning) {
        print('⚠️  Scan already in progress');
        return;
      }

      print('🔍 Starting Bluetooth scan...');
      _isScanning = true;

      // Listen to scan results
      _scanSubscription?.cancel();
      _scanSubscription = fbp.FlutterBluePlus.scanResults.listen((results) {
        for (fbp.ScanResult result in results) {
          if (result.device.name.isNotEmpty) {
            print('📱 Found device: ${result.device.name} (${result.device.id})');
            _onDeviceFound?.call(result.device);
          }
        }
      });

      // Start scan with filters
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
      print('❌ Scan error: $e');
      _isScanning = false;
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    try {
      if (!_isScanning) return;
      
      await fbp.FlutterBluePlus.stopScan();
      _isScanning = false;
      print('⏹️  Scan stopped');
    } catch (e) {
      print('❌ Error stopping scan: $e');
    }
  }

  /// Connect to device
  Future<bool> connectToDevice(fbp.BluetoothDevice device) async {
    try {
      print('🔗 Connecting to ${device.name}...');

      // Disconnect from current device first
      if (_connectedDevice != null && _connectedDevice!.id != device.id) {
        await disconnectDevice();
      }

      // Connect to new device
      await device.connect(
        autoConnect: false,
        timeout: const Duration(seconds: 15),
      );

      _connectedDevice = device;

      // Listen to connection state changes
      _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state) async {
        print('Connection state changed: $state');
        _connectionState = state;
        _onConnectionState?.call(state);

        if (state == fbp.BluetoothConnectionState.connected) {
          print('✅ Connected to ${device.name}');
          await _discoverServices();
        } else if (state == fbp.BluetoothConnectionState.disconnected) {
          print('❌ Disconnected from ${device.name}');
          _connectedDevice = null;
          _services = [];
          _writeCharacteristic = null;
        }
      });

      return true;
    } catch (e) {
      print('❌ Connection error: $e');
      _connectedDevice = null;
      return false;
    }
  }

  /// Disconnect from current device
  Future<void> disconnectDevice() async {
    try {
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
        print('✓ Disconnected');
      }
    } catch (e) {
      print('❌ Disconnect error: $e');
    }
  }

  /// Discover GATT services and characteristics
  Future<void> _discoverServices() async {
    try {
      if (_connectedDevice == null) {
        print('❌ No device connected');
        return;
      }

      print('🔎 Discovering services...');
      _services = await _connectedDevice!.discoverServices();

      if (_services.isEmpty) {
        print('⚠️  No services discovered');
        return;
      }

      print('✅ Found ${_services.length} service(s)');

      // Find a writable characteristic
      for (var service in _services) {
        print('📦 Service: ${service.uuid}');
        
        for (var characteristic in service.characteristics) {
          print('   Characteristic: ${characteristic.uuid}');
          print('      Properties: ${characteristic.properties}');

          // Look for write capabilities
          if (characteristic.properties.write ||
              characteristic.properties.writeWithoutResponse) {
            _writeCharacteristic = characteristic;
            print('   ✓ Found writable characteristic: ${characteristic.uuid}');
            _onServicesDiscovered?.call();
            return;
          }
        }
      }

      // If no standard write characteristic found, use first writable one found
      if (_writeCharacteristic == null) {
        print('⚠️  No standard writable characteristic found, searching...');
        _onServicesDiscovered?.call();
      }
    } catch (e) {
      print('❌ Service discovery error: $e');
    }
  }

  /// Send prediction result to connected device
  /// Supports both simple format: "NORMAL" or "ARRHYTHMIA"
  /// And detailed format: "NORMAL:99.5%"
  Future<bool> sendPredictionResult({
    required String label,
    required double confidence,
    bool includeConfidence = true,
  }) async {
    try {
      if (!isConnected || _connectedDevice == null) {
        print('⚠️  Not connected to device');
        return false;
      }

      // Format message
      String message = includeConfidence 
          ? '$label:${confidence.toStringAsFixed(1)}%'
          : label;

      return await sendData(message);
    } catch (e) {
      print('❌ Send prediction error: $e');
      return false;
    }
  }

  /// Send raw data to connected device
  Future<bool> sendData(String data) async {
    try {
      if (!isConnected || _connectedDevice == null) {
        print('⚠️  Not connected to device');
        return false;
      }

      if (_writeCharacteristic == null) {
        print('❌ No writable characteristic available');
        return false;
      }

      // Convert string to bytes
      List<int> bytes = utf8.encode(data);

      print('📤 Sending: $data (${bytes.length} bytes)');

      // Write to characteristic
      await _writeCharacteristic!.write(
        bytes,
        withoutResponse: _writeCharacteristic!.properties.writeWithoutResponse,
      );

      print('✅ Data sent successfully');
      return true;
    } catch (e) {
      print('❌ Send data error: $e');
      return false;
    }
  }

  /// Enable notifications for characteristic
  Future<void> enableNotifications(
      fbp.BluetoothCharacteristic characteristic) async {
    try {
      if (characteristic.properties.notify) {
        await characteristic.setNotifyValue(true);

        characteristic.onValueReceived.listen((List<int> event) {
          String receivedData = utf8.decode(event);
          print('📥 Received: $receivedData');
          _onDataReceived?.call(receivedData);
        });

        print('✓ Notifications enabled for ${characteristic.uuid}');
      }
    } catch (e) {
      print('❌ Error enabling notifications: $e');
    }
  }

  /// Cleanup resources
  Future<void> dispose() async {
    try {
      await stopScan();
      await disconnectDevice();
      await _scanSubscription?.cancel();
      await _connectionSubscription?.cancel();
      print('✓ BluetoothService disposed');
    } catch (e) {
      print('❌ Dispose error: $e');
    }
  }
}
