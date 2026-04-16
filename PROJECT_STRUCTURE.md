# 📂 Project Structure & File Reference

Complete documentation of all files in the ECG Monitor Flutter app.

---

## 🌳 Full Directory Tree

```
ecg_flutter_app/
│
├── 📄 Configuration Files
│   ├── pubspec.yaml                    # Flutter dependencies & assets
│   ├── analysis_options.yaml           # Lint rules
│   ├── .gitignore                      # Git-ignored files
│   └── .metadata                       # Flutter metadata (auto-generated)
│
├── 📚 Documentation
│   ├── README.md                       # Main documentation
│   ├── QUICK_START.md                  # 5-minute setup guide
│   ├── DEVELOPMENT.md                  # Developer guide
│   └── PROJECT_STRUCTURE.md            # This file
│
├── lib/                                # Source code
│   ├── main.dart                       # App entry & theme
│   ├── screens/
│   │   └── home_screen.dart            # Main UI screen
│   ├── services/
│   │   └── tflite_service.dart         # Model inference service
│   └── widgets/
│       └── result_card.dart            # Result display widget
│
├── assets/                             # App assets
│   ├── mamba_ecg.tflite                # TFLite model (4.5MB)
│   └── sample_ecg.csv                  # Sample test data
│
├── test/                               # Automated tests
│   └── example_test.dart               # Example unit tests
│
├── android/                            # Android-specific (auto-gen)
│   ├── app/
│   ├── gradle/
│   └── build.gradle
│
├── ios/                                # iOS-specific (auto-gen)
│   ├── Podfile
│   ├── Runner/
│   └── Frameworks/
│
└── .dart_tool/                         # Build artifacts (auto-gen)
```

---

## 📋 File Descriptions

### 🔧 Configuration Files

#### **pubspec.yaml**
**Purpose:** Flutter project configuration & dependency management
**Key Contents:**
- Project metadata (name, version, description)
- Flutter SDK version constraints
- Dependencies (tflite_flutter, file_picker)
- Asset configuration (model & sample data)
- Material design flag

**When to Edit:**
- Adding new packages
- Updating version number
- Configuring new assets

---

#### **analysis_options.yaml**
**Purpose:** Dart linter configuration
**Key Contents:**
- Lint rules for code quality
- Error level configurations
- File exclusions (.g.dart files)

**When to Edit:**
- Enforcing new code standards
- Suppressing specific warnings
- Configuring test behaviors

---

#### **.gitignore**
**Purpose:** Specify files to exclude from Git
**Key Contents:**
- Build artifacts (/build/)
- Dependency cache (.pub-cache/)
- IDE settings (.idea/)
- Platform-specific files (ios/, android/)

**When to Edit:**
- Adding new generated files
- Excluding sensitive data
- Platform-specific artifacts

---

### 📚 Documentation Files

#### **README.md**
**Audience:** Everyone (users & developers)
**Contents:**
- Feature overview
- Installation instructions
- Usage guide
- API reference
- Troubleshooting
- Future enhancements

**Accessibility:** Start here!

---

#### **QUICK_START.md**
**Audience:** New developers & users
**Contents:**
- Fast setup (3 commands)
- First test walkthrough
- Common issues & fixes
- Key features summary
- Verification checklist

**Best For:** Getting running in 5 minutes

---

#### **DEVELOPMENT.md**
**Audience:** Backend developers extending the app
**Contents:**
- Architecture diagram
- Component deep dives
- Data flow diagrams
- Extension guides
- Testing strategy
- Performance optimization
- Security considerations

**Best For:** Understanding or modifying codebase

---

#### **PROJECT_STRUCTURE.md**
**Audience:** Developers
**Contents:** This file! 📍
**Best For:** Finding files and understanding organization

---

### 💻 Source Code Files

#### **lib/main.dart** (≈100 lines)
**Purpose:** App initialization & theme setup

**Key Responsibilities:**
- Entry point (main() function)
- Create MaterialApp
- Define color scheme
- Configure Material Design 3
- Set dark/light themes
- Disable debug banner

**Key Classes:**
- `ECGMonitorApp` - Main app widget
- `ThemeData` - Visual configuration

**When to Edit:**
- Change app colors
- Modify themes
- Update app name
- Change initial route

**Code Structure:**
```
main()
  ↓
ECGMonitorApp
  ├── MaterialApp
  │   ├── ThemeData (Light)
  │   ├── ThemeData (Dark)
  │   └── HomeScreen
  └── ...
```

---

#### **lib/screens/home_screen.dart** (≈400 lines)
**Purpose:** Main user interface & logic

**Key Responsibilities:**
- Display UI components
- Handle file selection
- Generate sample ECG
- Run inference
- Display results
- Show alerts

**Key Classes:**
- `HomeScreen` - StatefulWidget
- `_HomeScreenState` - State management

**Key Methods:**
- `_initializeModel()` - Load TFLite model
- `_generateSampleECG()` - Create test data
- `_loadECGFile()` - Load CSV file
- `_runInference()` - Execute model
- `_showArrhythmiaAlert()` - Alert dialog

**Data Properties:**
```dart
_tfliteService          // Service instance
_ecgData                // Current ECG (187 values)
_result                 // Latest prediction
_isModelLoading         // Loading state
_isInferencing          // Inference state
```

**When to Edit:**
- Modify UI layout
- Add new buttons
- Change data processing
- Customize appearance

---

#### **lib/services/tflite_service.dart** (≈150 lines)
**Purpose:** TensorFlow Lite model management & inference

**Key Responsibilities:**
- Load model from assets
- Run inference
- Manage model resources
- Handle errors gracefully

**Key Classes:**
- `TFLiteService` - Singleton service class

**Key Methods:**
- `loadModel()` - Initialize model
- `runInference()` - Run prediction
- `close()` - Cleanup resources

**Singleton Pattern:**
```dart
factory TFLiteService() => _instance;
```

**When to Edit:**
- Add preprocessing steps
- Implement post-processing
- Change output format
- Add logging

---

#### **lib/widgets/result_card.dart** (≈200 lines)
**Purpose:** Beautiful result visualization

**Key Responsibilities:**
- Display prediction result
- Show confidence meter
- Color-code by status
- Render icons

**Key Classes:**
- `ResultCard` - Stateless widget

**Constructor Parameters:**
```dart
label          // "NORMAL" or "ARRHYTHMIA"
rawOutput      // 0.0-1.0 probability
confidence     // 0-100% confidence
isArrhythmia   // Boolean prediction
onAcknowledge  // Callback on button tap
```

**When to Edit:**
- Change card appearance
- Modify colors
- Update icons
- Change text layout

---

### 📦 Assets

#### **assets/mamba_ecg.tflite** (≈4.5 MB)
**Type:** TensorFlow Lite Model
**Format:** Binary TFLite format

**Specifications:**
- **Input:** [1, 187] - 187 ECG time points
- **Output:** Single probability value (0-1)
- **Optimization:** Quantized for edge deployment
- **Architecture:** Mamba SSM-based

**In pubspec.yaml:**
```yaml
assets:
  - assets/mamba_ecg.tflite
```

**Usage:**
- Loaded at app startup
- Held in memory
- Used for all predictions

---

#### **assets/sample_ecg.csv** (≈600 bytes)
**Type:** Test data file (187 numerical values)
**Format:** One value per line (newline-separated)

**Contents:** Sample ECG waveform
- Range: 0.0 - 1.0
- Total values: 187
- Purpose: Testing without data files

**Usage:**
- Load via file picker for testing
- Reference for file format
- Demonstrates expected structure

---

### 🧪 Test Files

#### **test/example_test.dart** (≈50 lines)
**Purpose:** Demonstrate unit testing patterns

**Test Cases:**
1. CSV parsing with 187 values
2. Data normalization (0-100 → 0-1)
3. Confidence calculation
4. Arrhythmia threshold detection

**How to Run:**
```bash
flutter test
```

**When to Extend:**
- Add new features
- Write regression tests
- Validate data processing
- Test UI components

---

### 🔴 Platform-Specific Files (Auto-Generated)

#### **android/** Directory
**Auto-generated:** Yes (by Flutter)
**Purpose:** Android app configuration

**Key Files:**
- `build.gradle` - Build configuration
- `AndroidManifest.xml` - App permissions
- `MainActivity.kt` - Android entry point

**When to Edit:**
- Add Android SDK level
- Request new permissions
- Configure Firebase
- Custom Android code

---

#### **ios/** Directory
**Auto-generated:** Yes (by Flutter)
**Purpose:** iOS app configuration

**Key Files:**
- `Podfile` - iOS dependencies
- `GeneratedPluginRegistrant.swift` - Plugin registration
- `Runner.xcodeproj` - Xcode project

**When to Edit:**
- Update iOS minimum version
- Add iOS permissions
- Configure Firebase
- Pod dependencies

---

### 🛠️ Build-Generated Files

#### **.dart_tool/** Directory
**Auto-generated:** Automatically managed
**Purpose:** Dart build cache & artifacts

**Contents:**
- Compiled Dart code
- Package snapshots
- Build metadata

**Management:** Don't manually edit; let Flutter manage

---

#### **.metadata**
**Auto-generated:** Automatically created
**Purpose:** Flutter project metadata

**Contains:**
- Project version
- Schema version
- Flutter version info

---

## 🔄 File Dependencies

### Dependency Chain
```
main.dart
  ↓ imports
home_screen.dart ←→ tflite_service.dart
  ↓ imports
result_card.dart
  ↓ uses
Material Design widgets
```

### Asset Dependencies
```
pubspec.yaml (declares)
  ↓
assets/
  ├── mamba_ecg.tflite (loaded by)
  │   └── tflite_service.dart
  └── sample_ecg.csv (used by)
      └── home_screen.dart
```

---

## 📊 File Size Reference

| File | Size | Type |
|------|------|------|
| mamba_ecg.tflite | 4.5 MB | Binary |
| sample_ecg.csv | 600 B | Text |
| main.dart | 3 KB | Source |
| home_screen.dart | 12 KB | Source |
| tflite_service.dart | 5 KB | Source |
| result_card.dart | 7 KB | Source |
| README.md | 8 KB | Docs |
| **Total** | **~4.6 MB** | - |

---

## 🎯 Common Editing Tasks

### Task: Change App Title
**Files to Edit:**
1. `lib/main.dart` - Line ~11 (MaterialApp title)
2. `pubspec.yaml` - Line ~1 (name)

### Task: Add New Button
**Files to Edit:**
1. `lib/screens/home_screen.dart` - Add in build()
2. `lib/screens/home_screen.dart` - Add handler method

### Task: Modify UI Colors
**Files to Edit:**
1. `lib/main.dart` - ThemeData configuration
2. `lib/widgets/result_card.dart` - Color constants

### Task: Add New Feature
**Files to Create:**
1. `lib/widgets/new_feature.dart` - Widget
2. Edit `lib/screens/home_screen.dart` - Import & use

### Task: Change Model
**Files to Edit:**
1. Replace `assets/mamba_ecg.tflite`
2. Update `lib/services/tflite_service.dart` - Shape validation
3. Update `pubspec.yaml` - Asset reference

---

## 📝 Naming Conventions

### Dart Files
```
single_word.dart               # Simple screens
multi_word_screen.dart         # Complex screens
multi_word_service.dart        # Services
multi_word_widget.dart         # Custom widgets
```

### Class Names
```
PascalCase                      # Widgets, Services
```

### Method Names
```
_privateMethod()                # Private (underscore prefix)
publicMethod()                  # Public
_pascalCaseScreenName           # Private state class
```

---

## 🔐 File Permissions (Android/iOS)

### android/AndroidManifest.xml
Required permissions:
- `READ_EXTERNAL_STORAGE` - Load files
- `INTERNET` - Optional (future sync)

### ios/Runner/Info.plist
Required keys:
- `NSLocalNetworkUsageDescription` - Network access

---

## 🚀 Build Output Files

When you build, Flutter generates:

**Android:**
```
build/app/outputs/flutter-apk/app-release.apk
build/app/outputs/bundle/release/app-release.aab
```

**iOS:**
```
build/ios/iphoneos/Runner.app
```

These are NOT in version control (.gitignore excludes them).

---

## 📦 Dependency Lock File

**pubspec.lock**
- Auto-generated when `flutter pub get`
- Contains exact dependency versions
- Ensures reproducible builds
- Should be in Git for team collaboration

---

## ✅ File Checklist

Before deployment, verify:
- [ ] `pubspec.yaml` has correct version
- [ ] Model file: `assets/mamba_ecg.tflite` exists
- [ ] All imports in Dart files resolve
- [ ] No TODO comments left unfixed
- [ ] Analysis passes: `flutter analyze`
- [ ] Tests pass: `flutter test`
- [ ] No git status conflicts

---

## 🔗 Quick File Navigation

**Need to change...**

| What | Where |
|------|-------|
| App colors | `lib/main.dart:20-35` |
| UI buttons | `lib/screens/home_screen.dart:250-350` |
| Model path | `lib/services/tflite_service.dart:40` |
| Result display | `lib/widgets/result_card.dart:30-60` |
| Dependencies | `pubspec.yaml:15-25` |
| Documentation | `README.md` or `QUICK_START.md` |

---

## 📞 Support

Confused about a file? 
1. Check this document
2. Read code comments (well-documented!)
3. See DEVELOPMENT.md for architecture
4. Check README.md for API reference

---

**Happy coding! 🎉**
