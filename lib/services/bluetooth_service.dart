import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;

/// Callbacks for Bluetooth events
typedef OnDeviceFound = void Function(fbp.BluetoothDevice device);
typedef OnConnectionState = void Function(fbp.BluetoothConnectionState state);
typedef OnDataReceived = void Function(String data);

/// Service for Bluetooth communication with wearable devices
/// Supports both peripheral (smartwatch) and central roles
class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();

  BluetoothService._internal();

  factory BluetoothService() {
    return _instance;
  }

  /// Bluetooth instance (built-in to flutter_blue_plus)
  // All operations use fbp.FlutterBluePlus static methods

  /// Connected device
  fbp.BluetoothDevice? _connectedDevice;

  /// Scanning state
  bool _isScanning = false;

  /// Connection state
  fbp.BluetoothConnectionState _connectionState =
      fbp.BluetoothConnectionState.disconnected;

  /// Callbacks
  OnDeviceFound? _onDeviceFound;
  OnConnectionState? _onConnectionState;
  OnDataReceived? _onDataReceived;

  /// Service UUIDs (standard GATT services)
  static const String ecgServiceUUID = '0000180a-0000-1000-8000-00805f9b34fb'; // Device Info
  static const String characteristicUUID = '00002a29-0000-1000-8000-00805f9b34fb'; // Manufacturer

  /// Getters
  bool get isConnected => _connectionState == fbp.BluetoothConnectionState.connected;
  bool get isScanning => _isScanning;
  fbp.BluetoothDevice? get connectedDevice => _connectedDevice;
  fbp.BluetoothConnectionState get connectionState => _connectionState;

  /// Register callbacks
  void onDeviceFound(OnDeviceFound callback) => _onDeviceFound = callback;
  void onConnectionState(OnConnectionState callback) =>
      _onConnectionState = callback;
  void onDataReceived(OnDataReceived callback) => _onDataReceived = callback;

  /// Check Bluetooth availability
  Future<bool> checkBluetoothAvailable() async {
    try {
      bool isSupported = await fbp.FlutterBluePlus.isSupported;
      print('Bluetooth supported: $isSupported');
      return isSupported;
    } catch (e) {
      print('❌ Error checking Bluetooth: $e');
      return false;
    }
  }

  /// Start scanning for devices
  Future<void> startScan({Duration timeout = const Duration(seconds: 5)}) async {
    try {
      if (_isScanning) {
        print('⚠️  Scan already in progress');
        return;
      }

      print('🔍 Starting Bluetooth scan...');
      _isScanning = true;

      fbp.FlutterBluePlus.scanResults.listen((results) {
        for (fbp.ScanResult result in results) {
          print('Found: ${result.device.name} - ${result.device.id}');
          _onDeviceFound?.call(result.device);
        }
      });

      fbp.FlutterBluePlus.startScan(timeout: timeout);

      // Auto-stop after timeout
      Future.delayed(timeout, () {
        stopScan();
      });
    } catch (e) {
      print('❌ Scan error: $e');
      _isScanning = false;
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    try {
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
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }

      // Connect to new device
      await device.connect(
        autoConnect: false,
        timeout: const Duration(seconds: 10),
      );

      _connectedDevice = device;

      // Listen to connection state
      device.connectionState.listen((state) {
        _connectionState = state;
        _onConnectionState?.call(state);

        if (state == fbp.BluetoothConnectionState.connected) {
          print('✅ Connected to ${device.name}');
          _discoverServices();
        } else if (state == fbp.BluetoothConnectionState.disconnected) {
          print('❌ Disconnected from ${device.name}');
          _connectedDevice = null;
        }
      });

      return true;
    } catch (e) {
      print('❌ Connection error: $e');
      return false;
    }
  }

  /// Discover GATT services
  Future<void> _discoverServices() async {
    try {
      if (_connectedDevice == null) return;

      print('🔎 Discovering services...');
      final services = await _connectedDevice!.discoverServices();

      for (var service in services) {
        print('Service: ${service.uuid}');
      }

      print('✅ Services discovered');
    } catch (e) {
      print('❌ Service discovery error: $e');
    }
  }

  /// Send prediction result to connected device
  Future<bool> sendPredictionResult(String label, double confidence) async {
    try {
      if (!isConnected || _connectedDevice == null) {
        print('⚠️  Not connected to device');
        return false;
      }

      // Format message
      String message = '$label|${confidence.toStringAsFixed(2)}';

      print('📤 Sending prediction: $message');

      // In production, you would:
      // 1. Discover services using _discoverServices()
      // 2. Find the appropriate GATT characteristic
      // 3. Write the prediction data to it
      
      // For simulation, we just simulate successful send
      print('✅ Prediction sent (simulated)');
      return true;
    } catch (e) {
      print('❌ Send error: $e');
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
      }
    } catch (e) {
      print('❌ Error enabling notifications: $e');
    }
  }

  /// Disconnect from device
  Future<void> disconnect() async {
    try {
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
        print('🔌 Disconnected');
      }
    } catch (e) {
      print('❌ Disconnect error: $e');
    }
  }

  /// Get system Bluetooth state
  Stream<fbp.BluetoothAdapterState> getAdapterStateStream() {
    return fbp.FlutterBluePlus.adapterState;
  }

  /// Dispose resources
  void dispose() {
    stopScan();
    disconnect();
    print('🔌 Bluetooth Service disposed');
  }
}
