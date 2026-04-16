# 🛠️ Development Guide - ECG Monitor App

Complete guide for developers extending or maintaining the ECG Monitor Flutter app.

---

## 📚 Architecture Overview

### Design Pattern: MVC + Service Layer

```
┌─────────────────────────────────────────┐
│          UI Layer (Screens)             │
│  ├── main.dart (Theme & Routing)        │
│  └── home_screen.dart (UI Logic)        │
└──────────────┬──────────────────────────┘
               │ Uses
┌──────────────▼──────────────────────────┐
│       Service Layer (Business Logic)    │
│  └── tflite_service.dart (Model Ops)    │
└──────────────┬──────────────────────────┘
               │ Manages
┌──────────────▼──────────────────────────┐
│     Data Layer (Model & I/O)            │
│  ├── TFLite Model (mamba_ecg.tflite)    │
│  └── CSV Files (ECG Data)               │
└─────────────────────────────────────────┘
```

### Widget Hierarchy

```
MaterialApp (main.dart)
  └── Scaffold (home_screen.dart)
      ├── AppBar
      ├── Body (Column)
      │   ├── Header Card
      │   ├── Input Section
      │   │   ├── Button: Load File
      │   │   └── Button: Generate Sample
      │   ├── Analysis Section
      │   │   └── Button: Analyze
      │   └── Result Section
      │       └── ResultCard (result_card.dart)
      └── SnackBar / Dialog (Alerts)
```

---

## 🔧 Core Components Deep Dive

### 1. TFLiteService (tflite_service.dart)

**Singleton Pattern**
```dart
factory TFLiteService() => _instance;
```
- Only one model instance
- Shared across app
- Memory efficient

**Key Methods:**

```dart
// Load model from assets
Future<bool> loadModel()

// Run inference
Future<Map<String, dynamic>> runInference(List<double> input)

// Clean up resources
Future<void> close()
```

**Error Handling:**
- Asset loading failures
- Shape mismatches
- Inference exceptions
- Resource management

### 2. HomeScreen (home_screen.dart)

**State Management:**
```dart
late TFLiteService _tfliteService;
List<double>? _ecgData;              // Current ECG data
Map<String, dynamic>? _result;       // Latest prediction
bool _isModelLoading = false;        // Loading state
bool _isInferencing = false;         // Inference state
```

**Data Processing Pipeline:**
```
CSV File / Generate Sample
    ↓
Parse/Create ECG values
    ↓
Validate (length == 187)
    ↓
Normalize (0-1 range)
    ↓
Pass to TFLiteService
    ↓
Display Result
```

### 3. ResultCard (result_card.dart)

**Stateless Widget** - No state management needed

**Dynamic Styling:**
- Color based on prediction
- Icons from prediction type
- Responsive layout
- Accessibility ready

---

## 📊 Data Flow

### ECG File Loading Flow

```
User taps "Load File"
    ↓
FilePicker.pickFiles() opens picker
    ↓
User selects CSV file
    ↓
Read file bytes → String content
    ↓
_parseCSV() extracts numbers
    ↓
Validate length (must be 187)
    ↓
setState() updates _ecgData
    ↓
UI shows "ECG Data Loaded" indicator
```

### Sample ECG Generation Flow

```
User taps "Generate Sample"
    ↓
Create oscillating sine wave pattern
    ↓
Add harmonic components
    ↓
Mix in realistic noise
    ↓
Normalize to 0-1 range
    ↓
setState() updates _ecgData
    ↓
Snackbar shows success
```

### Inference Flow

```
User taps "Analyze"
    ↓
Validate _ecgData exists
    ↓
setState(_isInferencing = true)
    ↓
Normalize ECG values
    ↓
Call tfliteService.runInference()
    ↓
Model processes [1, 187] tensor
    ↓
Extract output probability
    ↓
Calculate confidence
    ↓
setState() updates _result
    ↓
If arrhythmia: Show alert dialog
    ↓
Display ResultCard widget
```

---

## 🎨 UI Customization

### Change Primary Colors

**File:** `lib/main.dart`

```dart
theme: ThemeData(
  primarySwatch: Colors.blue,        // Main color
  appBarTheme: AppBarTheme(
    backgroundColor: Color(0xFF1E88E5),
  ),
)
```

### Modify Button Styling

**File:** `lib/main.dart`

```dart
elevatedButtonTheme: ElevatedButtonThemeData(
  style: ElevatedButton.styleFrom(
    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
    backgroundColor: Color(0xFF1E88E5),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
),
```

### Update Result Card Colors

**File:** `lib/widgets/result_card.dart`

```dart
final backgroundColor = isArrhythmia
    ? Color(0xFFFFEBEE)    // Red background
    : Color(0xFFE8F5E9);   // Green background
```

---

## 🔌 Extending the App

### Add New Feature: ECG Visualization

1. **Create new widget:**
```dart
// lib/widgets/ecg_chart.dart
import 'package:fl_chart/fl_chart.dart';

class ECGChart extends StatelessWidget {
  final List<double> ecgData;
  
  const ECGChart({required this.ecgData});
  
  @override
  Widget build(BuildContext context) {
    // Implement chart using fl_chart or similar
  }
}
```

2. **Add dependency in pubspec.yaml:**
```yaml
dependencies:
  fl_chart: ^0.65.0
```

3. **Use in HomeScreen:**
```dart
if (_ecgData != null)
  ECGChart(ecgData: _ecgData!)
```

### Add New Feature: Export Results

```dart
// In tflite_service.dart
Future<void> exportResult(Map<String, dynamic> result) async {
  final json = jsonEncode(result);
  // Save to file or upload to server
}
```

### Add New Feature: Cloud Sync

```dart
// In pubspec.yaml
dependencies:
  firebase_core: ^2.0.0
  cloud_firestore: ^4.0.0

// In tflite_service.dart
Future<void> syncToCloud(Map<String, dynamic> result) async {
  final doc = await FirebaseFirestore.instance
      .collection('ecg_results')
      .add(result);
}
```

---

## 🧪 Testing Strategy

### Unit Tests
```dart
// test/services/tflite_service_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TFLiteService', () {
    late TFLiteService service;
    
    setUp(() {
      service = TFLiteService();
    });
    
    test('Model loads successfully', () async {
      final result = await service.loadModel();
      expect(result, true);
      expect(service.isModelLoaded, true);
    });
    
    test('Inference returns valid output', () async {
      final input = List.filled(187, 0.5);
      final result = await service.runInference(input);
      
      expect(result.containsKey('isArrhythmia'), true);
      expect(result.containsKey('confidence'), true);
      expect(result['confidence'], greaterThanOrEqualTo(0));
      expect(result['confidence'], lessThanOrEqualTo(100));
    });
  });
}
```

### Widget Tests
```dart
// test/screens/home_screen_test.dart
void main() {
  group('HomeScreen', () {
    testWidgets('Display shows buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen())
      );
      
      expect(find.text('Load ECG File (CSV)'), findsOneWidget);
      expect(find.text('Generate Sample ECG'), findsOneWidget);
      expect(find.text('Analyze'), findsOneWidget);
    });
  });
}
```

### Run Tests
```bash
flutter test
flutter test --coverage
```

---

## 🐛 Debugging

### Enable Verbose Logging

```bash
flutter run -v
```

### Add Custom Debug Logs

```dart
print('🔍 Debug: ECG data length = ${_ecgData!.length}');
print('📊 Debug: Model output = ${_result!['rawOutput']}');
print('⚠️ Debug: Is arrhythmia = ${_result!['isArrhythmia']}');
```

### Inspect Widget Tree

```dart
// In main.dart
debugPrintBeginFrameBanner = true;
debugPrintEndFrameBanner = true;
```

### Use DevTools

```bash
flutter pub global activate devtools
flutter pub global run devtools

# Then run app with debug
flutter run
```

---

## 📦 Dependency Management

### Current Dependencies

```yaml
tflite_flutter: ^0.11.0  # Required for model inference
file_picker: ^6.1.1       # Required for file selection
cupertino_icons: ^1.0.2   # iOS-style icons
```

### Updating Dependencies

```bash
flutter pub outdated          # Check for updates
flutter pub upgrade          # Update all
flutter pub upgrade <package> # Update specific
```

### Adding New Dependency

1. Add to `pubspec.yaml`
2. Run `flutter pub get`
3. Import in code
4. Use in widgets

---

## 🚀 Performance Optimization

### Model Optimization
- Currently using quantized float16 model option available
- Consider converting to int8 for embedded devices

### UI Optimization
```dart
// Use const constructors
const Text('Label')  // Good
Text('Label')        // Less efficient

// Use RepaintBoundary for complex widgets
RepaintBoundary(
  child: ECGChart()
)

// Avoid rebuild of expensive widgets
const SizedBox(height: 16)  // Won't rebuild
```

### Memory Management
```dart
// Proper cleanup
@override
void dispose() {
  _tfliteService.close();  // Free model resources
  super.dispose();
}
```

---

## 📝 Code Style Guidelines

### Naming Conventions

```dart
// Classes - PascalCase
class HomeScreen { }
class TFLiteService { }
class ResultCard { }

// Functions/Methods - camelCase
void _initializeModel() { }
Future<bool> loadModel() { }

// Variables - camelCase
List<double>? _ecgData;
bool _isModelLoading = false;

// Constants - camelCase with const prefix
const Duration timeout = Duration(seconds: 5);
```

### Documentation

```dart
/// Load the TFLite model
/// 
/// Returns true if model loaded successfully,
/// false otherwise.
Future<bool> loadModel() async {
  // Implementation
}
```

### Comments

```dart
// TODO: Add real-time visualization
// NOTE: Model output is binary classification
// FIXME: Handle memory leaks in older devices
```

---

## 🔒 Security Considerations

### File Picker Security
```dart
// Validate file before processing
if (!_isValidECGFile(file)) {
  throw Exception('Invalid file format');
}

// Limit file size
if (file.size > 1024 * 1024) {
  throw Exception('File too large');
}
```

### Model Security
- Store model in assets (bundled with app)
- Don't expose raw model output to untrusted sources
- Validate input data range

### Sensitive Data
- Don't log raw ECG values in production
- Secure any cloud synchronization with HTTPS
- Handle permissions properly for file access

---

## 🌐 Platform-Specific Code

### Android-Specific
```dart
import 'dart:io' show Platform;

if (Platform.isAndroid) {
  // Android-specific code
}
```

### iOS-Specific
```dart
if (Platform.isIOS) {
  // iOS-specific code (e.g., using Cupertino widgets)
}
```

---

## 📋 Checklist for New Developer

- [ ] Clone repository
- [ ] Run `flutter pub get`
- [ ] Read README.md
- [ ] Review main.dart
- [ ] Study TFLiteService
- [ ] Write simple unit test
- [ ] Add a feature to home screen
- [ ] Run app on device
- [ ] Review lint issues: `flutter analyze`

---

## 🚀 Deployment Checklist

Before releasing:
- [ ] Run `flutter analyze` - zero errors
- [ ] Run `flutter test` - all tests pass
- [ ] Build APK: `flutter build apk --release`
- [ ] Test on Android 5+ device
- [ ] Test file picker
- [ ] Test model inference
- [ ] Check memory usage
- [ ] Verify alerts display correctly
- [ ] Update version in pubspec.yaml
- [ ] Create release tag in git

---

## 📞 Troubleshooting

### Issue: Hot Reload Doesn't Work
```bash
flutter clean
flutter run
```

### Issue: Lint Errors
```bash
flutter analyze
# Fix issues shown
```

### Issue: Dependency Conflict
```bash
rm pubspec.lock
flutter pub get
```

### Issue: Model File Not Found
- Verify assets/mamba_ecg.tflite exists
- Check pubspec.yaml assets section
- Run `flutter pub get`

---

## 📚 References

- Flutter Docs: https://flutter.dev/docs
- Dart Language: https://dart.dev/guides
- TFLite Flutter: https://pub.dev/packages/tflite_flutter
- Material Design: https://material.io/design
- State Management: https://flutter.dev/docs/development/data-and-backend/state-mgmt/intro

---

**Happy developing! 🎉**

Questions? Check code comments or create an issue.
