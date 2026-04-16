import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Callbacks for Bluetooth events
typedef OnDeviceFound = void Function(BluetoothDevice device);
typedef OnConnectionState = void Function(BluetoothConnectionState state);
typedef OnDataReceived = void Function(String data);

/// Service for Bluetooth communication with wearable devices
/// Supports both peripheral (smartwatch) and central roles
class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();

  BluetoothService._internal();

  factory BluetoothService() {
    return _instance;
  }

  /// Bluetooth instance
  final FlutterBluePlus _flutterBlue = FlutterBluePlus();

  /// Connected device
  BluetoothDevice? _connectedDevice;

  /// Discovered services
  List<BluetoothService>? _services;

  /// Scanning state
  bool _isScanning = false;

  /// Connection state
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;

  /// Callbacks
  OnDeviceFound? _onDeviceFound;
  OnConnectionState? _onConnectionState;
  OnDataReceived? _onDataReceived;

  /// Service UUIDs (standard GATT services)
  static const String ecgServiceUUID = '0000180a-0000-1000-8000-00805f9b34fb'; // Device Info
  static const String characteristicUUID = '00002a29-0000-1000-8000-00805f9b34fb'; // Manufacturer

  /// Getters
  bool get isConnected => _connectionState == BluetoothConnectionState.connected;
  bool get isScanning => _isScanning;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  BluetoothConnectionState get connectionState => _connectionState;

  /// Register callbacks
  void onDeviceFound(OnDeviceFound callback) => _onDeviceFound = callback;
  void onConnectionState(OnConnectionState callback) =>
      _onConnectionState = callback;
  void onDataReceived(OnDataReceived callback) => _onDataReceived = callback;

  /// Check Bluetooth availability
  Future<bool> checkBluetoothAvailable() async {
    try {
      bool isSupported = await FlutterBluePlus.isSupported;
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

      FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          print('Found: ${result.device.name} - ${result.device.id}');
          _onDeviceFound?.call(result.device);
        }
      });

      FlutterBluePlus.startScan(timeout: timeout);

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
      await FlutterBluePlus.stopScan();
      _isScanning = false;
      print('⏹️  Scan stopped');
    } catch (e) {
      print('❌ Error stopping scan: $e');
    }
  }

  /// Connect to device
  Future<bool> connectToDevice(BluetoothDevice device) async {
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

        if (state == BluetoothConnectionState.connected) {
          print('✅ Connected to ${device.name}');
          _discoverServices();
        } else if (state == BluetoothConnectionState.disconnected) {
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
        for (var characteristic in service.characteristics) {
          print('  - Characteristic: ${characteristic.uuid}');
        }
      }

      _services = services;
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
      List<int> bytes = utf8.encode(message);

      print('📤 Sending: $message');

      // Find writable characteristic
      if (_services != null) {
        for (var service in _services!) {
          for (var characteristic in service.characteristics) {
            if (characteristic.properties.write ||
                characteristic.properties.writeWithoutResponse) {
              await characteristic.write(bytes);
              print('✅ Data sent successfully');
              return true;
            }
          }
        }
      }

      print('⚠️  No writable characteristic found');
      return false;
    } catch (e) {
      print('❌ Send error: $e');
      return false;
    }
  }

  /// Enable notifications for characteristic
  Future<void> enableNotifications(
      BluetoothCharacteristic characteristic) async {
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
  Stream<BluetoothAdapterState> getAdapterStateStream() {
    return FlutterBluePlus.adapterState;
  }

  /// Dispose resources
  void dispose() {
    stopScan();
    disconnect();
    print('🔌 Bluetooth Service disposed');
  }
}
