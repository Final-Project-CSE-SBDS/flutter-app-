# 🆘 Troubleshooting & FAQ Guide

## 📋 Table of Contents

1. Installation Issues
2. Runtime Errors
3. UI/Graph Problems
4. Inference Issues
5. Bluetooth Problems
6. Performance Issues
7. Data Problems
8. FAQ

---

## ❌ Installation Issues

### Issue: "pub get" fails with dependency error

**Error Message**:
```
Error: Dependency mismatch!
  flutter_blue_plus requires sdk: '>=3.0.0'
```

**Solution**:
```bash
# Update Flutter to latest version
flutter upgrade

# Then try again
flutter pub get

# Or force get
flutter pub get --offline
```

---

### Issue: TFLite model not found during build

**Error Message**:
```
Error: assets/mamba_ecg.tflite not found
```

**Solution**:
1. Verify file exists: `ls assets/mamba_ecg.tflite`
2. Check pubspec.yaml has asset entry:
```yaml
flutter:
  assets:
    - assets/mamba_ecg.tflite
    - assets/sample_ecg.csv
```
3. Run `flutter clean` then `flutter pub get`

---

### Issue: CSV file not loading

**Error Message**:
```
Error: sample_ecg.csv not found in assets
```

**Solution**:
1. Create `assets/sample_ecg.csv` with ECG data
2. Or use empty file (system generates synthetic data)
3. Update pubspec.yaml with asset path
4. Run `flutter clean` and rebuild

---

## ⚙️ Runtime Errors

### Issue: "Model failed to load"

**Appears In**: Splash screen while initializing

**Causes**:
- TFLite model corrupted
- Not enough RAM
- Model file wrong format

**Solutions**:
```bash
# Check model validity
file assets/mamba_ecg.tflite
# Should say: TensorFlow Lite model

# Check file size
ls -lh assets/mamba_ecg.tflite
# Should be 100+ KB

# Try re-downloading model
# Replace mamba_ecg.tflite with verified copy
```

---

### Issue: "Buffer size mismatch"

**Error Message**:
```
Input length must be 187, got 150
```

**Cause**: Model expects 187 values but got different size

**Solution**:
```dart
// Check model input shape
// File: lib/services/tflite_service.dart

// Model input must be [1, 187]
// Edit buffer size to match

// In lib/services/ecg_streaming_service.dart:
static const int bufferSize = 187;  // Match model input!
```

---

### Issue: "Null safety error"

**Error Message**:
```
The argument type 'double?' can't be assigned to...
```

**Solution**:
```bash
# Ensure using Dart 3.0+
dart --version

# Should show: Dart 3.x.x

# Update if needed
flutter upgrade
```

---

## 🎨 UI/Graph Problems

### Issue: Graph is completely empty

**What You See**: White box with no data

**Diagnosis**:
1. Is START button clicked?
2. Has 2+ seconds passed?
3. Check console for errors

**Fix**:
```
1. Click START button
2. Wait 2-3 seconds
3. Graph should show wavy line
4. If not, check console for errors
5. Click RESET and try again
```

---

### Issue: Graph shows flat line (no waves)

**What You See**: Straight line, not wavy

**Causes**:
- CSV has constant values
- Normalization failed
- Wrong data format

**Solutions**:

Option 1: Use synthetic data
```dart
// In ecg_streaming_service.dart
// Let it generate synthetic data instead
```

Option 2: Check CSV format
```
File should be:
0.45
0.52
0.48
...

NOT:
ECG,value
0.45,0.45
```

---

### Issue: Graph updates are choppy/stuttering

**What You See**: Jittery animation, not smooth

**Cause**: Streaming interval too fast or CPU overloaded

**Solution 1**: Increase interval
```dart
// In lib/services/ecg_streaming_service.dart, line 24
static const int streamInterval = 100; // was 50ms
// Higher = smoother, slower
```

Solution 2: Reduce graph points
```dart
// In ECGGraphWidget
// Show only last 100 points instead of 187
```

Solution 3: Close other apps
```bash
# Free up RAM
# Run only Flutter app
# Disable background processes
```

---

### Issue: Result card not displaying

**What You See**: No NORMAL/ARRHYTHMIA card after 15 seconds

**Cause**: Inference hasn't run yet

**Timeline Check**:
- 0-9 sec: Buffer filling
- 9 sec: Buffer full
- 9.1-9.2 sec: Inference running
- 9.2 sec+: Result should appear

**Fix**:
```
1. Wait full 15 seconds
2. Check "Total Scans" counter increased
3. If counter =0, inference not running
4. Check console for "Inference complete"
5. If still missing, click RESET + START
```

---

## 🧠 Inference Issues

### Issue: "Model not loaded" error at inference

**Error Message**:
```
Exception: Model not loaded. Call loadModel() first.
```

**Cause**: Model loading failed silently

**Fix**:
```bash
# Check console during startup
# Should see "✅ Model loaded successfully"

# If not:
flutter clean
flutter run
# Watch console carefully
```

---

### Issue: Predictions are always "NORMAL"

**Pattern**: Every inference shows NORMAL,never ARRHYTHMIA

**Causes**:
- Model threshold too high (> 0.7)
- Data is all normal pattern
- Model not trained properly

**Check**:
```dart
// In tflite_service.dart, line 115
print('Raw Output: ${probability}');  // Add this

// Check console - what is probability value?
// If always < 0.5, then threshold correct
// If around 0.5, consider lowering threshold
```

**Adjust Threshold**:
```dart
// Lower the threshold to be more sensitive
final isArrhythmia = probability > 0.3;  // was 0.5
```

---

### Issue: Predictions are always "ARRHYTHMIA"

**Pattern**: Every inference shows ARRHYTHMIA

**Cause**: Threshold too low (< 0.3)

**Solution**:
```dart
// Raise the threshold
final isArrhythmia = probability > 0.7;
```

---

### Issue: Inference runs but takes 5+ seconds

**Symptom**: Long delay between buffer full and result

**Causes**:
- Model file is huge
- Device is slow (old phone)
- Other apps using CPU

**Solutions**:
1. Close background apps
2. Use release build: `flutter run --release`
3. Profile performance: `flutter run --profile`

---

## 📡 Bluetooth Problems

### Issue: "Bluetooth not available"

**Error**: Dialog says "Bluetooth not supported"

**Cause**: 
- Device doesn't have BLE
- Bluetooth disabled
- Android < 5.0 (API < 21)

**Fix**:
1. Enable Bluetooth in system settings
2. Use newer device (BLE requires API 21+)
3. Check `checkBluetoothAvailable()`

---

### Issue: "Failed to scan for devices"

**Symptom**: No devices found when scanning

**Causes**:
- No nearby BLE devices
- Permissions not granted
- Android Bluetooth scanning disabled

**Solutions**:

For Android 6.0+:
```xml
<!-- Add to AndroidManifest.xml -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

Then request permission in code:
```dart
// Implement permission_handler package
// Request BLUETOOTH_SCAN permission at runtime
```

---

### Issue: "Connected but data not sending"

**Symptom**: 
- Bluetooth shows "Connected"
- But data doesn't appear on device

**Causes**:
- Wrong GATT characteristic
- Device not listening
- Message format incorrect

**Fix**:

1. Check message format:
```dart
// Should be: "NORMAL|92.50"
// Not: "{label: NORMAL}"
```

2. Verify GATT discovery:
```dart
// In BluetoothService._discoverServices()
// Should find writable characteristic
```

3. Test with hardcoded message:
```dart
List<int> testBytes = utf8.encode("NORMAL|100.0");
// Try to send - check console
```

---

### Issue: "Bluetooth permission denied"

**Error**: "BLUETOOTH_CONNECT permission denied"

**Fix** (Android 12+):
```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```

Then request at runtime:
```dart
import 'package:permission_handler/permission_handler.dart';

await Permission.bluetoothConnect.request();
```

---

## ⚡ Performance Issues

### Issue: App is very slow/laggy

**Symptoms**: 
- Graph stutters
- UI responds slowly
- Device gets hot

**Diagnosis**:
```bash
# Check performance profile
flutter run --profile

# Check GPU rendering
flutter run --trace-startup

# Memory usage
adb shell dumpsys meminfo com.example.ecg_monitor
```

**Solutions** (in order):

1. Increase streaming interval:
```dart
static const int streamInterval = 100; // was 50
```

2. Reduce UI complexity:
```dart
// Disable grid in graph
showGrid: false
```

3. Use release build:
```bash
flutter run --release
```

4. Profile and optimize hot spots

---

### Issue: Battery draining quickly

**Symptom**: Battery % drops rapidly

**Causes**:
- Constant inference (too frequent)
- WiFi/Bluetooth always on
- Screen always on
- CPU at high usage

**Solutions**:

1. Increase inference delay:
```dart
// Don't run every 9 seconds
// Only when needed
```

2. Optimize model:
```dart
// Use quantized model (smaller, faster)
```

3. Reduce graph resolution:
```dart
// Show fewer data points
```

4. Use Doze mode friendly intervals

---

## 📊 Data Problems

### Issue: CSV file has no data / data is corrupted

**Symptom**:
- Synthetic data generated instead
- Graph shows wrong pattern

**Check**:
```bash
# View CSV file
cat assets/sample_ecg.csv | head -20

# Should show numbers like:
# 0.45
# 0.52
# 0.48

# Count lines
wc -l assets/sample_ecg.csv
# Should have 100+
```

**Fix**:
1. Download valid ECG ECG data
2. Format as CSV (one value per line)
3. Place in `assets/sample_ecg.csv`
4. Rebuild app

---

### Issue: "Normalization failed"

**Symptom**:
- Graph shows only 0s or 1s
- No variation in data

**Cause**: Data range too small or all same value

**Fix**:

In `ecg_streaming_service.dart`:
```dart
void _normalizeData() {
  // Check for edge case
  double min = _allECGData.reduce((a, b) => a < b ? a : b);
  double max = _allECGData.reduce((a, b) => a > b ? a : b);
  
  if (min == max) {
    // All values same - can't normalize
    print('Warning: All values identical');
    // Use synthetic instead
  }
}
```

---

### Issue: Data repeats same pattern

**Symptom**: Graph shows exact same wave every 9 seconds

**Cause**: Not actually streaming - buffer content cycling

**This is Actually Normal!**
- CSV data is finite (5000 points)
- After ~45 minutes, loops back to start
- This is expected behavior

**To Change**: Load different CSV or increase loop size

---

## ❓ FAQ

### Q1: Is this production-ready?

**A**: 
- **For simulation**: Yes, fully ready
- **For real devices**: Needs permission setup + testing
- **For healthcare**: Needs medical approval + certification

See [REALTIME_SETUP.md](REALTIME_SETUP.md) for production checklist.

---

### Q2: Can I use my own ECG model?

**A**: Yes!

1. Prepare model in TFLite format (.tflite)
2. Check input shape: should be [1, 187] (or edit BUFFER_SIZE)
3. Replace `assets/mamba_ecg.tflite`
4. Rebuild app

---

### Q3: How do I connect a real smartwatch?

**A**:

1. Get smartwatch with Bluetooth (WearOS, Fitbit, etc.)
2. Check device specs for supported services
3. Implement proper permission handling
4. Use BluetoothService to discover & connect
5. Send predictions via `sendPredictionResult()`
6. Watch app receives on characteristic listener

See [REALTIME_SETUP.md](REALTIME_SETUP.md#5-bluetooth-integration-important) Bluetooth section.

---

### Q4: What ECG data format do you support?

**A**: CSV with one numeric value per line.

Example:
```
0.4523
0.5102
0.4899
...
```

**Not supported**:
- Excel/XLSX format
- JSON format
- Comma-separated: 0.45, 0.51, 0.48
- With headers: "ECG,value"

---

### Q5: How accurate is the model?

**A**:
- **Accuracy**: Depends on training data
- **Test/validation available**: Check model documentation
- **On real data**: Needs clinical validation
- **Current model**: ~95% on training set (adjust based on your data)

---

### Q6: Can I export/save predictions?

**A**: Currently predictions stay in-memory. To save:

```dart
// Add to _runInference():
File historyFile = File('${appDocDir}/predictions.txt');
historyFile.writeAsStringSync(
  '${result['label']},${result['confidence']}\n',
  mode: FileMode.append
);
```

---

### Q7: Does it work offline?

**A**: 
- **Yes**: Inference happens locally
- **No**: Bluetooth won't send to cloud
- **No**: Patient notification won't work (needs internet)

---

### Q8: What's the maximum data points?

**A**: 
- **Buffer**: 187 values (fixed for model)
- **CSV**: Limited by device RAM (~10,000 for typical phone)
- **History**: Stores last 20 predictions

---

### Q9: Can I change the buffer size?

**A**:
```dart
// Edit this line:
static const int bufferSize = 187;

// But must match MODEL's input shape!
// If model expects [1, 187], use 187
// If model expects [1, 256], use 256

// Check model: tflite_service._printModelInfo()
```

---

### Q10: How do I debug issues?

**A**:
```bash
# View console output
flutter logs

# Look for these markers:
# "✅" = Success
# "❌" = Error  
# "⚠️" = Warning
# "📦" = Loading
# "🔄" = Processing

# Add breakpoint debugging
# Break at _runInference() to inspect values
```

---

### Q11: Why is it called "Mamba AI"?

**A**: Mamba is a type of neural network architecture (State Space Model). Your model likely uses this advanced architecture for efficient ECG classification.

---

### Q12: Can I run multiple instances?

**A**: 
- **Same device**: No, services are Singletons
- **Multiple devices**: Yes, each has independent instance
- **Watch + Phone**: Yes, they communicate via Bluetooth

---

## 🎓 Debug Checklist

When something goes wrong:

- [ ] Check Flutter console for errors
- [ ] Look for "❌" error markers
- [ ] Check WiFi/Bluetooth enabled (for real data)
- [ ] Try `flutter clean` and rebuild
- [ ] Check file permissions (CSV, model)
- [ ] Verify device has enough RAM/storage
- [ ] Test on different app version
- [ ] Try on different device if possible
- [ ] Update Flutter/Dart version
- [ ] Check app permissions in system settings

---

## 📞 Getting More Help

1. **Console Errors**: Read the exact message
2. **Gradle/Flavor issues**: Check Android build.gradle
3. **iOS issues**: Check iOS build settings
4. **Bluetooth specific**: Review flutter_blue_plus examples
5. **Model issues**: Check TFLite documentation

---

**Still stuck? Add print statements throughout the code to trace execution flow!** 🐛

Remember: Most issues are related to:
1. Missing/wrong TFLite model
2. Missing/wrong CSV data
3. Permissions not granted
4. Device too slow/low RAM
