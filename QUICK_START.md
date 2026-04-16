# 🚀 Quick Start Guide - ECG Monitor Flutter App

Get up and running with the ECG Arrhythmia Detection app in 5 minutes!

## ⚡ TL;DR (Fast Setup)

```bash
# 1. Get dependencies
flutter pub get

# 2. Run on your device
flutter run
```

That's it! 🎉

---

## 📋 Step-by-Step Setup

### Prerequisites Check

Before starting, verify you have:

```bash
# Check Flutter version (need 3.0+)
flutter --version

# Check system readiness
flutter doctor
```

Expected output should show:
- ✅ Flutter framework
- ✅ Dart SDK
- ✅ Android SDK or Xcode (depending on platform)
- ✅ IDE

### Step 1: Get the Code

Navigate to the project:

```bash
cd ecg_flutter_app
```

### Step 2: Install Dependencies

```bash
flutter pub get
```

This will download:
- `tflite_flutter` - Model inference
- `file_picker` - File selection
- All transitive dependencies

### Step 3: Run the App

**On Android Emulator/Device:**
```bash
flutter run
```

**On iOS Simulator:**
```bash
flutter run -d ios
```

**On Physical Device:**
```bash
flutter run
```

**In Release Mode (faster):**
```bash
flutter run --release
```

---

## 🎮 Your First Test

Once the app launches:

### Option A: Quick Test
1. Tap **"Generate Sample ECG"** button
   - App creates test data (no file needed!)
   - You'll see: "ECG Data Loaded: 187 values"

2. Tap **"Analyze"** button
   - Model analyzes the data
   - Result card appears in ~1 second

3. Check the result:
   - 🟢 Green = Normal heartbeat
   - 🔴 Red = Arrhythmia detected
   - Shows confidence percentage

### Option B: Upload Your Own Data
1. Prepare a CSV file with exactly **187 ECG values**
2. Tap **"Load ECG File (CSV)"**
3. Select your CSV file
4. Tap **"Analyze"**

---

## 🛠️ Troubleshooting

### Issue: "flutter command not found"
**Solution:**
- Install Flutter from https://flutter.dev/docs/get-started/install
- Verify PATH environment variable includes Flutter

### Issue: "No devices available"
**Solution:**
```bash
# List available devices
flutter devices

# Launch emulator manually
emulator -list-avds
emulator @device_name
```

### Issue: "Model not found" error
**Solution:**
- Verify file exists: `assets/mamba_ecg.tflite`
- Rebuild: `flutter clean && flutter pub get && flutter run`

### Issue: App crashes on "Analyze"
**Solution:**
- Test on **physical device** (emulators may not support TFLite)
- Or use a recent Android Studio emulator with ARM support

### Issue: Dependencies fail to install
**Solution:**
```bash
# Clean everything
flutter clean
rm pubspec.lock

# Fresh install
flutter pub get
```

---

## 📁 Project Organization

```
ecg_flutter_app/
├── pubspec.yaml          ← Dependencies config
├── lib/
│   ├── main.dart         ← Entry point
│   ├── screens/          ← UI screens
│   │   └── home_screen.dart
│   ├── services/         ← Business logic
│   │   └── tflite_service.dart
│   └── widgets/          ← Reusable UI components
│       └── result_card.dart
├── assets/               ← Model & sample data
│   ├── mamba_ecg.tflite
│   └── sample_ecg.csv
└── README.md             ← Full documentation
```

---

## 🎯 Features to Try

### 1. Generate Realistic ECG
```
Tap: "Generate Sample ECG"
→ Creates 187-point ECG signal
→ Based on sine wave harmonics
→ Auto-normalized
```

### 2. Load Custom Data
```
Tap: "Load ECG File (CSV)"
→ Pick any CSV file
→ Parses numeric values
→ Must have 187 values
```

### 3. Real-Time Analysis
```
Tap: "Analyze"
→ Less than 1 second
→ Color-coded result
→ Confidence percentage
```

### 4. Alert System
```
If Arrhythmia detected:
→ Popup alert appears
→ Recommends doctor visit
→ Tap "OK" to dismiss
```

---

## 💡 Code Structure Explained

### main.dart - Initialization
- App theme & routing
- Material Design setup
- Debug settings

### home_screen.dart - Main UI
- ECG data input (file or generate)
- Inference trigger
- Result display

### tflite_service.dart - AI Logic
- Model loading from assets
- Inference execution
- Error handling

### result_card.dart - Result Display
- Visual result card
- Confidence visualization
- Status colors & icons

---

## 📊 Data Processing

### Input Format
- **Type:** List of 187 floating-point values
- **Range:** Any (app normalizes automatically)
- **Format:** CSV (comma or newline separated)

### Normalization
```
Raw Value: 1.5
Min: 0, Max: 3
Normalized: (1.5 - 0) / (3 - 0) = 0.5
```

### Model Output
```
Raw: 0.3 → Normal (< 0.5)
Raw: 0.7 → Arrhythmia (>= 0.5)
Confidence: max(0.3, 0.7) × 100% = 70%
```

---

## 🔧 Build Commands Reference

```bash
# Development
flutter run                    # Debug build

# Production
flutter build apk             # Android APK
flutter build appbundle       # Android App Bundle
flutter build ios             # iOS app

# Utilities
flutter clean                 # Clean build cache
flutter pub get               # Install dependencies
flutter pub upgrade           # Update dependencies
flutter analyze               # Lint code
flutter test                  # Run tests
```

---

## 🎨 UI Customization

### Change Theme Colors

Edit **main.dart**:
```dart
primarySwatch: Colors.blue,        // Change here
appBarTheme: AppBarTheme(
  backgroundColor: Color(0xFF1E88E5),  // Change here
),
```

### Modify UI Text

Edit **home_screen.dart**:
```dart
Text('Your Title Here'),  // Change app title
Text('Your Button Text'), // Change button labels
```

---

## 📚 Learning Resources

### Flutter Documentation
- https://flutter.dev/docs
- Widget catalog: https://flutter.dev/docs/development/ui/widgets

### TFLite Flutter
- Package: https://pub.dev/packages/tflite_flutter
- Examples: https://github.com/tensorflow/flutter-mediapipe

### CSV Parsing
- file_picker: https://pub.dev/packages/file_picker
- csv package: https://pub.dev/packages/csv

---

## 🐛 Debug Tips

### Enable Verbose Logging
```bash
flutter run -v
```

### Print Console Messages
In code:
```dart
print('Debug message'); // Shows in console
```

### Check Model Status
```dart
print('Model Loaded: ${_tfliteService.isModelLoaded}');
```

---

## ✅ Verification Checklist

Before deploying:
- [ ] Flutter version 3.0+
- [ ] Model file in assets
- [ ] No lint errors: `flutter analyze`
- [ ] Runs without crashes
- [ ] Sample generation works
- [ ] File picker works
- [ ] Model inference works
- [ ] Alerts display on arrhythmia

---

## 📱 Device Support

| Platform | Min Version | Status |
|----------|-------------|--------|
| Android  | SDK 21 (5.0) | ✅ Supported |
| iOS      | 11.0        | ✅ Supported |
| Web      | N/A         | ⚠️ Not tested |

---

## 🚀 Next Steps

After setup:

1. ✅ **Test** - Generate sample ECG and analyze
2. 🎨 **Customize** - Change colors, text, layout
3. 📊 **Extend** - Add visualization graphs
4. 📤 **Deploy** - Build APK/IPA for distribution
5. 🌐 **Integrate** - Connect to backend API

---

## 💬 Need Help?

1. Check **README.md** for detailed docs
2. Review **code comments** in source files
3. Read error messages carefully
4. Try `flutter doctor` to diagnose issues
5. Search Flutter GitHub issues for solutions

---

**Happy coding! 🎉**

Got questions? Read the full README.md in the project root.
