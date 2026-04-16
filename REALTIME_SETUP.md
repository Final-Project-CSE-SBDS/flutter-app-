# 📱 Real-Time ECG Monitoring System - Setup & Deployment Guide

## 🎯 Overview

Your Flutter app has been upgraded from a basic ECG classifier to a **complete real-time monitoring system** with Bluetooth integration and smartwatch simulation.

### ✨ Key Features Implemented

1. **Real-Time ECG Streaming** - Simulates live ECG sensor data from CSV
2. **Live ECG Graph** - Smooth real-time visualization using fl_chart
3. **Continuous Inference** - ML model runs automatically when buffer fills (187 values)
4. **Arrhythmia Alerts** - Popup notifications on abnormal detection
5. **Bluetooth Integration** - Send predictions to paired wearables
6. **Watch Display** - Smartwatch simulation screen
7. **Prediction History** - Track recent classifications with timestamps

---

## 🚀 Getting Started

### 1. Install Dependencies

```bash
cd c:\Users\Dancing\ wolf\Desktop\AP\ecg_flutter_app
flutter clean
flutter pub get
```

### 2. Ensure CSV Data File Exists

Check that `assets/sample_ecg.csv` has ECG data:
- **Format**: Single column of numeric values (one value per row)
- **Expected rows**: 100+ values (should have at least 187 for first inference)
- **Example**:
  ```
  0.45
  0.52
  0.48
  ...
  ```

If your CSV is empty or missing, the system generates synthetic data automatically.

### 3. Run the App

```bash
flutter run
```

---

## 📊 How the System Works

### ECG Data Flow

```
Input CSV
    ↓
ECGStreamingService (loads & normalizes)
    ↓
Timer (50ms intervals) ← One value per tick
    ↓
Buffer (rolling window of 187 values)
    ↓
Buffer Full? YES
    ↓
TFLiteService (inference on [1, 187])
    ↓
Result: NORMAL or ARRHYTHMIA
    ↓
UI Update + Bluetooth Send
    ↓
Loop continues (circular buffer)
```

### Buffer Management

- **Size**: 187 values (fixed model input shape)
- **Interval**: 50ms between data points
- **Total Stream Time**: ~9.35 seconds per full buffer cycle
- **Behavior**: Loops back to CSV start when finished

---

## 🎮 Using the App

### Main Screen (HomeScreen)

#### Status Banner
- Shows "● Live Monitoring..." when active
- Displays buffer fill percentage

#### Controls
1. **START** - Begin real-time ECG streaming
2. **STOP** - Pause monitoring
3. **RESET** - Clear all data and restart

#### Displays
- **Live ECG Waveform** - Graph updates in real-time
- **Latest Prediction Card** - Shows most recent classification
- **Statistics**:
  - Total Scans: Number of inferences performed
  - Buffer Fill: % of 187 values loaded
  - Data Points: Total ECG values available
  
#### Recent Predictions
- Shows last 20 classifications with:
  - Prediction (Normal/Arrhythmia)
  - Confidence percentage
  - Timestamp

### Watch Screen (/watch route)

Access it via navigation or URL:
```
http://localhost:12345/watch
```

Features:
- **Connection Status** - Shows Bluetooth connection state
- **Large Status Display** - 💚 NORMAL or ⚠️ ARRHYTHMIA
- **Mini ECG Graph** - Watch-optimized visualization
- **Reading History** - Last 10 predictions in timeline

---

## 📱 UI Components

### 1. **ECGGraphWidget** (lib/widgets/ecg_graph.dart)
- Full featured line chart with grid
- Axes labels and touch tooltips
- Color-coded (blue=normal, red=arrhythmia)

### 2. **MinimalECGGraph**
- Compact watch-display version
- No grid, minimalist design
- Ideal for small screens

### 3. **ResultCard** (lib/widgets/result_card.dart)
- Shows prediction label
- Confidence percentage with progress bar
- Colored indicator (green/red)

---

## 🔧 Configuration

### Modify Streaming Speed

Edit [lib/services/ecg_streaming_service.dart](lib/services/ecg_streaming_service.dart#L24):

```dart
static const int streamInterval = 50; // milliseconds
// Lower = faster, Higher = slower
// Typical: 20-100ms
```

### Change Buffer Size

Edit [lib/services/ecg_streaming_service.dart](lib/services/ecg_streaming_service.dart#L21):

```dart
static const int bufferSize = 187; // MUST match model input!
```

### Modify Arrhythmia Threshold

Edit [lib/services/tflite_service.dart](lib/services/tflite_service.dart#L115):

```dart
final isArrhythmia = probability > 0.5; // Threshold
// 0.5 = 50% confidence threshold
// Can adjust for sensitivity
```

---

## 📡 Bluetooth Integration

### Current Implementation (Simulation Mode)

The app is configured for simulation. To use **real Bluetooth**:

1. **Configure Permissions** (Android):
   - Edit `android/app/build.gradle.kts`
   - Ensure `permissions` include BLE scopes

2. **Request Runtime Permissions**:
   ```dart
   // In HomeScreen._connectBluetooth():
   // Implement permission_handler package
   ```

3. **Enable Device Scanning**:
   ```dart
   await _bluetoothService.startScan();
   // Returns list of BluetoothDevice
   ```

4. **Connect to Device**:
   ```dart
   bool connected = await _bluetoothService.connectToDevice(device);
   ```

5. **Send Data**:
   ```dart
   await _bluetoothService.sendPredictionResult('NORMAL', 92.5);
   ```

### Default Setup
- Bluetooth is ready to send but in simulation mode
- Click BT icon for demo dialog
- Real data sends when buffer fills

---

## 🧪 Testing

### Test Scenario 1: Basic Streaming

```
1. Click START
2. Watch buffer fill to 100%
3. First inference should complete
4. Monitor graph updates
5. Check prediction history
```

### Test Scenario 2: Alert System

```
1. If model detects Arrhythmia:
   - Alert popup shows
   - Waveform turns red
   - Prediction card highlights
```

### Test Scenario 3: Watch Display

```
1. Run on two devices
2. On Device 1: Start monitoring
3. On Device 2: Navigate to /watch
4. Watch screen simulates incoming data
```

---

## 🐛 Troubleshooting

### Issue: "Model failed to load"
**Solution**: 
- Check `assets/mamba_ecg.tflite` exists
- Verify `pubspec.yaml` asset line

### Issue: "No ECG data"
**Solution**:
- Check `assets/sample_ecg.csv` has data
- System generates synthetic data if empty

### Issue: Graph not updating
**Solution**:
- Ensure START button was clicked
- Check ECGStreamingService.initialize() completed
- Verify streamInterval isn't too slow

### Issue: No inference running
**Solution**:
- Wait for buffer to fill (187 values at 20 Hz = ~9 sec)
- Check console for "Inference complete" messages
- Restart app

### Issue: Bluetooth errors
**Solution**:
- In simulation mode, BT errors are safe to ignore
- For real hardware, add proper permission handling
- Check flutter_blue_plus documentation

---

## 📚 File Structure

```
lib/
├── main.dart                          ← Routes setup
├── screens/
│   ├── home_screen.dart              ← Main monitoring UI
│   └── watch_screen.dart             ← Smartwatch display
├── services/
│   ├── tflite_service.dart           ← ML inference
│   ├── ecg_streaming_service.dart    ← Real-time streaming
│   └── bluetooth_service.dart        ← BLE communication
└── widgets/
    ├── ecg_graph.dart                ← Live chartwidgets
    └── result_card.dart              ← Prediction display

assets/
├── mamba_ecg.tflite                  ← ML model
└── sample_ecg.csv                    ← ECG data
```

---

## 🔐 Permissions (Production)

### Android (android/app/src/main/AndroidManifest.xml)

Add for Bluetooth:
```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
```

Add for file access (if loading custom CSVs):
```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

### iOS (ios/Runner/Info.plist)

Add:
```xml
<key>NSBluetoothPeripheralUsageDescription</key>
<string>ECG App needs Bluetooth to send heart data to wearables</string>
<key>NSBluetoothCentralUsageDescription</key>
<string>ECG App needs Bluetooth to connect to heart rate monitors</string>
```

---

## 📈 Performance Tips

1. **Reduce Graph Points**: Filter display data to reduce render load
2. **Increase Buffer Size**: Larger buffers mean less frequent inference
3. **Batch Predictions**: Process multiple buffers before UI update
4. **Offload Bluetooth**: Use isolates for BLE send operations

---

## 🎓 Integration Points

### Add Custom CSV Loading
```dart
// In home_screen.dart _loadECGFile()
// Use file_picker or document_picker package
```

### Add Real Sensor Integration
```dart
// Replace ECGStreamingService with:
// - health package for real heart rate data
// - Custom sensor plugin via method channel
```

### Add Cloud Sync
```dart
// Send predictions to backend:
// - Firebase Firestore
// - Custom REST API
// - GraphQL endpoint
```

### Add Advanced Alerts
```dart
// Integration with:
// - Firebase Cloud Messaging (FCM)
// - Local notifications
// - SMS alerts
// - Call healthcare provider
```

---

## 📞 Support & Resources

- **Flutter**: https://flutter.dev
- **TFLite Flutter**: https://github.com/tensorflow/flutter-mediapipe
- **Flutter BLE**: https://pub.dev/packages/flutter_blue_plus
- **FL Chart**: https://github.com/imaNNeoFighT/fl_chart

---

## ✅ Checklist: Before Production

- [ ] Load real ECG data (not synthetic)
- [ ] Test with actual wearable device
- [ ] Implement proper permissions
- [ ] Add error handling for all services
- [ ] Test offline mode
- [ ] Verify model accuracy on target data
- [ ] Optimize battery usage
- [ ] Add data encryption for Bluetooth
- [ ] Implement logging for debugging
- [ ] Get medical device certification (if applicable)

---

**✨ System is ready! Press START to begin real-time monitoring. ✨**
