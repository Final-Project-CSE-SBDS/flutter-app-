import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/home_screen.dart';
import 'screens/watch_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();
  
  // Request all required permissions
  print('🔔 Requesting notification permission...');
  await _requestNotificationPermission();
  
  print('🔵 Requesting Bluetooth permissions...');
  await _requestBluetoothPermissions();
  
  runApp(const ECGMonitorApp());
}

/// Request notification permission for Android 13+
Future<void> _requestNotificationPermission() async {
  try {
    final status = await Permission.notification.request();
    if (status.isGranted) {
      print('✅ Notification permission granted');
    } else if (status.isDenied) {
      print('⚠️ Notification permission denied by user');
    } else if (status.isPermanentlyDenied) {
      print('❌ Notification permission permanently denied - open app settings');
      openAppSettings();
    }
  } catch (e) {
    print('❌ Error requesting notification permission: $e');
  }
}

/// Request Bluetooth permissions for Android 12+
Future<void> _requestBluetoothPermissions() async {
  try {
    // Request BLUETOOTH_SCAN (Android 12+)
    final scanStatus = await Permission.bluetoothScan.request();
    if (scanStatus.isGranted) {
      print('✅ BLUETOOTH_SCAN permission granted');
    } else {
      print('⚠️ BLUETOOTH_SCAN permission denied');
    }
    
    // Request BLUETOOTH_CONNECT (Android 12+)
    final connectStatus = await Permission.bluetoothConnect.request();
    if (connectStatus.isGranted) {
      print('✅ BLUETOOTH_CONNECT permission granted');
    } else {
      print('⚠️ BLUETOOTH_CONNECT permission denied');
    }
    
    // Request ACCESS_FINE_LOCATION (required for BLE scanning)
    final locationStatus = await Permission.location.request();
    if (locationStatus.isGranted) {
      print('✅ ACCESS_FINE_LOCATION permission granted');
    } else {
      print('⚠️ ACCESS_FINE_LOCATION permission denied');
    }
    
  } catch (e) {
    print('❌ Error requesting Bluetooth permissions: $e');
  }
}

/// Main app widget for ECG Arrhythmia Classification with Real-Time Monitoring
class ECGMonitorApp extends StatelessWidget {
  const ECGMonitorApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ECG Monitor - Mamba AI',
      theme: ThemeData(
        /// Primary color scheme
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
        
        /// App bar theme
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E88E5),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        
        /// Button theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            backgroundColor: const Color(0xFF1E88E5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        
        /// Card theme
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/watch': (context) => const WatchScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
