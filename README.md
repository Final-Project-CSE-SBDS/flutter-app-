# ECG Monitor - Mamba AI Flutter App

A complete Flutter mobile application for ECG Arrhythmia Classification using a TensorFlow Lite (TFLite) model based on the Mamba neural network architecture.

## 🎯 Features

✅ **TFLite Model Integration** - Pre-trained Mamba ECG classification model
✅ **ECG Data Input** - Load CSV files with ECG signals
✅ **Sample Generation** - Generate realistic ECG-like samples for testing
✅ **Real-time Inference** - Fast model prediction with confidence scores
✅ **Alert System** - Automatic alerts for abnormal heartbeat detection
✅ **Modern UI** - Clean, responsive Material Design interface
✅ **Health Monitoring** - Color-coded indicators (Normal: Green, Arrhythmia: Red)

## 📦 Requirements

- Flutter 3.0+ (with Dart SDK 3.0+)
- Android SDK 21+ or iOS 11+
- TensorFlow Lite support

## 🚀 Setup & Installation

### 1. Prerequisites

Ensure you have Flutter installed and configured:

```bash
flutter --version
flutter doctor
```

### 2. Install Dependencies

Navigate to the project directory and run:

```bash
flutter pub get
```

### 3. Build the App

**For Android:**
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

**For iOS:**
```bash
flutter build ios --release
```

### 4. Run the App

```bash
flutter run
```

Or in release mode:
```bash
flutter run --release
```

## 📁 Project Structure

```
ecg_flutter_app/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── screens/
│   │   └── home_screen.dart         # Main UI screen
│   ├── services/
│   │   └── tflite_service.dart      # TFLite model service
│   └── widgets/
│       └── result_card.dart         # Result display widget
├── assets/
│   ├── mamba_ecg.tflite             # TFLite model
│   └── sample_ecg.csv               # Sample ECG data
├── pubspec.yaml                     # Flutter dependencies
└── README.md                         # This file
```

## 🎮 Usage Guide

### Step 1: Load ECG Data

Choose one of two methods:

**Option A: Load from File**
- Tap "Load ECG File (CSV)"
- Select a CSV file with ECG values (187 values)
- File format: Single column or comma-separated values

**Option B: Generate Sample**
- Tap "Generate Sample ECG"
- App creates a realistic ECG-like signal
- Perfect for testing without data files

### Step 2: Analyze

- Tap "Analyze" button
- Model runs inference on loaded ECG data
- Wait for result (typically <1 second)

### Step 3: View Result

Results displayed on a **Result Card** showing:
- **Prediction**: NORMAL ✓ or ARRHYTHMIA ⚠️
- **Confidence**: Percentage (0-100%)
- **Status Icon & Color**: Visual indicator
- **Raw Output**: Model probability value

### Step 4: Alerts

If **ARRHYTHMIA** detected:
- Popup alert appears: "⚠️ Abnormal Heartbeat Detected"
- Recommends consulting healthcare professional
- Tap "OK" to dismiss

## 📊 Model Information

**Model Name:** Mamba ECG Arrhythmia Classifier
**Framework:** TensorFlow Lite
**Input Shape:** [1, 187]
- 1 batch size
- 187 ECG time-steps

**Output:** Classification probability (0-1)
- Output < 0.5 → **NORMAL** ✓
- Output ≥ 0.5 → **ARRHYTHMIA** ⚠️

**Confidence Calculation:**
- Confidence = max(output, 1-output) × 100%

## 🔧 Technical Details

### Core Components

**1. TFLiteService (services/tflite_service.dart)**
- Singleton pattern for model management
- `loadModel()` - Initialize model from assets
- `runInference(List<double>)` - Execute prediction
- `close()` - Resource cleanup

**2. HomeScreen (screens/home_screen.dart)**
- Main UI with step-by-step workflow
- File picker integration
- Sample ECG generation
- Error handling & notifications

**3. ResultCard (widgets/result_card.dart)**
- Beautiful result visualization
- Color-coded status indicators
- Confidence progress bar
- Responsive design

### Dependencies

```yaml
tflite_flutter: ^0.11.0   # TFLite inference
file_picker: ^6.1.1       # File selection
flutter: SDK              # Core framework
```

## 📈 ECG Data Format

### CSV File Requirements

**Format 1: Single Column**
```csv
0.45
0.46
0.48
...
(187 rows total)
```

**Format 2: Comma-Separated**
```csv
0.45, 0.46, 0.48, ...
```

**Requirements:**
- Must have exactly **187 values**
- Values should be **normalized 0-1** (but app handles normalization)
- Can be integers or decimals

### Generated Sample

The app generates synthetic ECG using:
- Multiple sine wave harmonics
- Realistic waveform simulation
- Added noise for authenticity
- Auto-normalized to 0-1 range

## 🎨 UI Features

### Modern Design
- Material Design 3 (Material You)
- Rounded corners & elevation
- Color-coded status (Green/Red)
- Responsive layout for all screen sizes

### Visual Indicators
- **Green (NORMAL)**: Steady heart icon, green border
- **Red (ARRHYTHMIA)**: Warning icon, red border
- Progress bar for confidence
- Loading spinner during inference

## ⚠️ Error Handling

The app gracefully handles:
- ❌ Model loading failures
- ❌ Invalid file formats
- ❌ Incorrect data length
- ❌ Inference errors
- ❌ Missing permissions

All errors display user-friendly messages.

## 🔐 Permissions

### Android
- `READ_EXTERNAL_STORAGE` - For file selection

### iOS
- Document browsing permissions required

## 📱 Tested Platforms

- ✅ Android 5.0+ (API 21+)
- ✅ iOS 11.0+
- ✅ Tablet & Phone screens

## 🐛 Debugging

### Enable Debug Logging

Logs are printed in console with emojis:
- 📦 Loading operations
- 🔄 Processing steps
- ✅ Success messages
- ❌ Error messages
- ⚠️ Warnings
- 💡 Info messages

### Check Model Status

In `HomeScreen`:
```dart
print('Model Loaded: ${_tfliteService.isModelLoaded}');
```

### Common Issues

**Issue:** "Model not found"
- **Solution:** Verify `assets/mamba_ecg.tflite` exists and is in `pubspec.yaml`

**Issue:** "Invalid input shape"
- **Solution:** Ensure ECG data has exactly 187 values

**Issue:** App crashes on inference
- **Solution:** Deploy to actual device (not all emulators support TFLite)

## 📚 Code Comments

All code includes:
- ✓ Function documentation
- ✓ Inline comments
- ✓ Parameter descriptions
- ✓ Return value explanations
- ✓ Error handling notes

## 🎓 For Beginners

**Key Concepts:**

1. **Model Service Pattern**: Centralized model management
2. **State Management**: Using `StatefulWidget` for app state
3. **File I/O**: CSV parsing and data handling
4. **UI Components**: Cards, buttons, dialogs
5. **Error Handling**: Try-catch & user feedback

## 🚀 Performance Tips

- Model loads once at app startup
- Inference runs in <1 second typically
- Optimized for production use
- Minimal memory footprint

## 📋 API Reference

### TFLiteService

```dart
// Singleton instance
TFLiteService service = TFLiteService();

// Load model
await service.loadModel();

// Check status
bool isReady = service.isModelLoaded;

// Run inference
Map<String, dynamic> result = await service.runInference([...187 values...]);
// Returns:
// {
//   'isArrhythmia': bool,
//   'rawOutput': double,
//   'confidence': double,
//   'label': String,
//   'color': String
// }

// Cleanup
await service.close();
```

## 📞 Support

For issues or questions:
1. Check console logs for error messages
2. Verify model file exists in assets
3. Ensure ECG data has 187 values
4. Test on physical device if emulator fails

## 📄 License

This project is part of the ECG Arrhythmia Classification System.

## ✨ Future Enhancements

- 📊 Real-time ECG visualization
- 📈 Historical data tracking
- 🔔 Notification system
- 📤 Cloud synchronization
- 🌐 Data export features
- 🎯 Multi-model support

---

**Version:** 1.0.0
**Last Updated:** 2024
**Status:** Production Ready ✅
