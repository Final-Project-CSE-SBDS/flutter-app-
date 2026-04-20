import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart' show Color;
import 'dart:io' show Platform;

/// Service for handling local notifications on Android/iOS
/// Displays ECG prediction results on smartwatch and device
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  
  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  bool _isInitialized = false;

  NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  /// Get initialization status
  bool get isInitialized => _isInitialized;

  // ============= Initialization =============
  /// Initialize the notification service
  /// Must be called in main.dart before using notifications
  Future<void> initialize() async {
    try {
      if (_isInitialized) return;

      _notificationsPlugin = FlutterLocalNotificationsPlugin();

      // Android initialization
      if (Platform.isAndroid) {
        await _initializeAndroid();
      }
      // iOS initialization
      else if (Platform.isIOS) {
        await _initializeIOS();
      }

      _isInitialized = true;
      _log('✅ Notification service initialized');
    } catch (e) {
      _logError('Failed to initialize notification service: $e');
      rethrow;
    }
  }

  /// Android-specific initialization
  Future<void> _initializeAndroid() async {
    try {
      _log('Initializing Android notifications...');
      
      // Initialize Android notifications plugin
      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      );

      await _notificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          _log('Notification tapped: ${response.payload}');
        },
      );
      _log('✓ Flutter Local Notifications plugin initialized');

      // Create notification channel for high priority alerts
      const androidChannel = AndroidNotificationChannel(
        'ecg_predictions',
        'ECG Predictions',
        description: 'High priority notifications for ECG predictions',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
        showBadge: true,
      );

      // Create the channel
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(androidChannel);
        _log('✓ Android notification channel "ecg_predictions" created');
      } else {
        _logWarn('Could not resolve Android notification implementation');
      }
      
      _log('✅ Android notifications configured successfully');
    } catch (e) {
      _logError('Failed to initialize Android notifications: $e');
    }
  }

  /// iOS-specific initialization
  Future<void> _initializeIOS() async {
    try {
      final iosPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();

      // Request permissions
      final granted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

      if (granted == true) {
        _log('✅ iOS notification permissions granted');
      } else {
        _logWarn('⚠️  iOS notification permissions not granted');
      }

      _log('✅ iOS notifications configured');
    } catch (e) {
      _logError('Failed to initialize iOS notifications: $e');
    }
  }

  // ============= Notification Methods =============
  /// Show notification for NORMAL ECG result
  /// Green heart indicator for normal rhythm
  Future<void> showNormalResult({
    String? confidence,
  }) async {
    if (!_isInitialized) {
      _logWarn('Notification service not initialized');
      return;
    }

    try {
      String message = '💚 Heart Rhythm Normal';
      if (confidence != null) {
        message = '$message\n$confidence';
      }

      await _showNotification(
        id: 1001,
        title: '✅ ECG Result',
        message: message,
        isArrhythmia: false,
      );

      _log('📢 Normal result notification sent');
    } catch (e) {
      _logError('Failed to show normal result notification: $e');
    }
  }

  /// Show notification for ARRHYTHMIA ECG result
  /// Red warning indicator for abnormal rhythm
  /// Includes vibration and sound alert
  Future<void> showArrhythmiaAlert({
    String? confidence,
    bool enableVibration = true,
    bool enableSound = true,
  }) async {
    if (!_isInitialized) {
      _logWarn('Notification service not initialized');
      return;
    }

    try {
      String message = '⚠️ Abnormal Heartbeat Detected';
      if (confidence != null) {
        message = '$message\n$confidence';
      }

      await _showNotification(
        id: 1002,
        title: '🚨 ECG Alert',
        message: message,
        isArrhythmia: true,
        enableVibration: enableVibration,
        enableSound: enableSound,
      );

      _log('🔴 Arrhythmia alert notification sent');
    } catch (e) {
      _logError('Failed to show arrhythmia alert notification: $e');
    }
  }

  /// Internal method to show notification
  /// Handles platform-specific details
  Future<void> _showNotification({
    required int id,
    required String title,
    required String message,
    required bool isArrhythmia,
    bool enableVibration = false,
    bool enableSound = false,
  }) async {
    try {
      _log('💭 Preparing notification (ID: $id, Title: $title)');
      
      // Android notification details
      final androidDetails = AndroidNotificationDetails(
        'ecg_predictions',
        'ECG Predictions',
        channelDescription: 'High priority notifications for ECG predictions',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: enableVibration,
        playSound: enableSound,
        autoCancel: true,
        showWhen: true,
        usesChronometer: false,
        styleInformation: BigTextStyleInformation(
          message,
          contentTitle: title,
          htmlFormatBigText: true,
        ),
        // Color for notification
        color: isArrhythmia ? const Color.fromARGB(255, 255, 0, 0) : const Color.fromARGB(255, 0, 204, 0),
      );

      // iOS notification details
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      // Show notification on both platforms
      _log('📤 Sending notification to system...');
      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: message,
        notificationDetails: NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        ),
      );
      
      _log('✅ Notification displayed successfully (ID: $id)');

      // Optional: Add device vibration for arrhythmia
      if (isArrhythmia && enableVibration && Platform.isAndroid) {
        _performVibration();
      }
    } catch (e) {
      _logError('❌ Error showing notification: $e');
      _logError('   ID: $id, Title: $title');
      _logError('   Message: $message');
      rethrow;
    }
  }

  // ============= Utility Methods =============
  /// Perform device vibration pattern
  /// Three short vibrations for alerts
  void _performVibration() {
    try {
      // In a real implementation, you would use:
      // import 'package:vibration/vibration.dart';
      // Vibration.vibrate(duration: 500);
      
      _log('📳 Vibration triggered (requires vibration package)');
    } catch (e) {
      _logError('Vibration error: $e');
    }
  }

  /// Cancel specific notification by ID
  Future<void> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id: id);
      _log('Notification $id cancelled');
    } catch (e) {
      _logError('Failed to cancel notification: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
      _log('All notifications cancelled');
    } catch (e) {
      _logError('Failed to cancel all notifications: $e');
    }
  }

  // ============= Logging =============
  void _log(String message) {
    print('📬 Notifications: $message');
  }

  void _logWarn(String message) {
    print('🟡 Notifications: $message');
  }

  void _logError(String message) {
    print('🔴 Notifications: $message');
  }

  /// Cleanup
  Future<void> dispose() async {
    try {
      await cancelAllNotifications();
      _isInitialized = false;
      _log('Notification service disposed');
    } catch (e) {
      _logError('Error disposing notification service: $e');
    }
  }
}
