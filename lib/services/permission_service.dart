import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;

/// Service for handling Bluetooth and location permissions on Android
/// BLE scanning on Android 12+ requires location permissions
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();

  PermissionService._internal();

  factory PermissionService() {
    return _instance;
  }

  /// Request Bluetooth permissions (Android 12+)
  /// Returns true if permissions are granted
  Future<bool> requestBluetoothPermissions() async {
    try {
      // Only applies to Android
      if (!Platform.isAndroid) {
        print('🟢 PermissionService: Non-Android platform, permissions not required');
        return true;
      }

      print('🟡 PermissionService: Requesting Bluetooth permissions...');

      // Check if Bluetooth is supported
      final bool isSupported = await fbp.FlutterBluePlus.isSupported;

      if (isSupported) {
        print('✅ PermissionService: Bluetooth is supported and available');
        return true;
      } else {
        print('❌ PermissionService: Bluetooth is not supported on this device');
        return false;
      }
    } catch (e) {
      print('❌ PermissionService: Error requesting permissions: $e');
      return false;
    }
  }

  /// Check if app has necessary permissions
  Future<bool> hasBluetoothPermissions() async {
    try {
      if (!Platform.isAndroid) {
        return true;
      }

      // Verify Bluetooth is available
      bool isSupported = await fbp.FlutterBluePlus.isSupported;
      return isSupported;
    } catch (e) {
      print('❌ PermissionService: Error checking permissions: $e');
      return false;
    }
  }
}
