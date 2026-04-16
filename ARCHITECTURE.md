# 🏗️ System Architecture & Design Documentation

## 📐 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter UI Layer                         │
│  ┌──────────────────┐                ┌──────────────────┐  │
│  │  HomeScreen      │                │  WatchScreen     │  │
│  │ (Real-Time Mon.) │                │ (Smartwatch RX)  │  │
│  └────────┬─────────┘                └──────────────────┘  │
└───────────┼────────────────────────────────────────────────┘
            │
     ┌──────┴──────────────────┐
     │                         │
┌────▼──────────┐      ┌──────▼───────────┐
│ HomeScreen    │      │ WatchScreen      │
│ Widgets       │      │ Callbacks        │
├───────────────┤      ├──────────────────┤
│ • ECGGraph    │      │ • onDataReceived │
│ • ResultCard  │      │ • updateStatus() │
│ • StatCards   │      └──────────────────┘
└────┬──────────┘
     │
┌────▼────────────────────────────────────────────────────┐
│ Service Layer (Business Logic)                         │
│ ┌──────────────────┐  ┌──────────────┐ ┌─────────────┐ │
│ │ ECGStreaming     │  │ TFLiteService│ │ Bluetooth   │ │
│ │ Service          │  │              │ │ Service     │ │
│ ├──────────────────┤  ├──────────────┤ ├─────────────┤ │
│ │ • loadECGFromCSV │  │ • loadModel()│ │ • connect() │ │
│ │ • startStreaming │  │ • runInfer() │ │ • sendData()│ │
│ │ • fillBuffer()   │  │ • callbacks  │ │ • discover()│ │
│ │ • normalize()    │  │              │ │             │ │
│ └──────────┬───────┘  └──────┬───────┘ └──────┬──────┘ │
└────────────┼──────────────────┼─────────────────┼─────────┘
             │                  │                 │
      ┌──────▼──────┐   ┌──────▼──────┐  ┌──────▼──────┐
      │ Timer Loop  │   │ TFLite Lib  │  │ Flutter BLE │
      │ (50ms)      │   │ (Inference) │  │ (Comms)     │
      └─────────────┘   └─────────────┘  └─────────────┘
```

---

## 🔄 Data Flow Diagram

### ECG Classification Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│                     REAL-TIME ECG LOOP                          │
└─────────────────────────────────────────────────────────────────┘

 CSV File                  Timer Tick (50ms)           Buffer Check
    │                            │                            │
    ├──────────┐                 │                            │
    │ 5000+ ECG│                 │                            │
    │ values   │◄────────────────┼────────────────────────────┤
    └──────────┘                 │                            │
         │                       │                            │
         ├───► Normalize ◄───────┼────────────────────────────┤
         │    (0-1 range)        │                            │
         │                       │                            │
         └──► Get Next ◄─────────┘                            │
              Value                                           │
              (index++)                                       │
                 │                                            │
                 ├──────────────────────────────────────────┐ │
                 │ Add to Buffer                            │ │
                 │ (rolling window)                         │ │
                 │                                          │ │
                 └──► Buffer[187] = [v1, v2, ..., v187]    │ │
                                                            │ │
                      Is Full? ◄──────────────────────────┬─┘ │
                      │                                   │    │
                      ├─ NO ───► Wait next tick ─────────┘    │
                      │                                        │
                      └─ YES ──────────┐                       │
                                       │                       │
                                       ▼                       │
                        ┌──────────────────────────┐           │
                        │ TFLite Inference        │           │
                        │ Input: [1, 187]        │           │
                        │ Output: probability    │           │
                        └──────┬───────────────────┘           │
                               │                               │
                     ┌─────────┴──────────┐                    │
                     │                    │                    │
                     ▼                    ▼                    │
                 prob > 0.5           prob ≤ 0.5              │
                     │                    │                    │
         ┌───────────┴──┐      ┌──────────┴────────┐           │
         │              │      │                   │           │
         ▼              ▼      ▼                   ▼           │
    ARRHYTHMIA ⚠️   NORMAL 💚   ARRHYTHMIA ⚠️  NORMAL 💚      │
    (Confidence)   (Confidence)                                │
         │              │      │                   │           │
         └──────────┬───┘      └─────────┬─────────┘           │
                    │                    │                     │
                    ▼                    ▼                     │
             Update UI Results                                │
             ├─ Prediction Label                              │
             ├─ Confidence % (progress bar)                   │
             ├─ Graph Color (red/green)                       │
             ├─ Add to History                                │
             └─ Send via Bluetooth (if connected)             │
                                                              │
             ┌──────────────────────────────────────┐         │
             │ Clear Buffer                         │         │
             │ (start fresh for next inference)     │         │
             └──────────────────────────────────────┘         │
                           │                                   │
                           └───► LOOP ◄─────────────────────────┘
```

---

## 🎛️ Service Layer Architecture

### 1. ECGStreamingService

**Responsibility**: Manage real-time ECG data streaming

```
┌─────────────────────────────────────────┐
│  ECGStreamingService                    │
├─────────────────────────────────────────┤
│ PROPERTIES:                             │
│  - _allECGData: List<double>           │  (5000+ values)
│  - _buffer: List<double>               │  (187 values)
│  - _currentIndex: int                  │  (stream position)
│  - _streamTimer: Timer                 │  (50ms tick)
│  - _isStreaming: bool                  │  (active flag)
│                                         │
│ CALLBACKS:                              │
│  - onDataUpdate()                      │  (50ms)
│  - onInferenceReady()                  │  (when full)
│                                         │
│ METHODS:                                │
│  - initialize()                        │  load CSV
│  - startStreaming()                    │  start timer
│  - stopStreaming()                     │  stop timer
│  - reset()                             │  clear buffer
│  - _processStreamTick()                │  core 50ms logic
│  - _normalizeData()                    │  0-1 scaling
│  - _generateSyntheticData()            │  if CSV empty
└─────────────────────────────────────────┘
```

**Key Timing**:
- CSV Load: async, ~100ms
- Per-Tick: 50ms (20 samples/sec)
- Full Buffer: 187 × 50ms = 9,350ms (~9.3 sec)

### 2. TFLiteService

**Responsibility**: ML model management and inference

```
┌─────────────────────────────────────────┐
│  TFLiteService                          │
├─────────────────────────────────────────┤
│ PROPERTIES:                             │
│  - _interpreter: Interpreter           │  TFLite runtime
│  - _isModelLoaded: bool                │  state flag
│  - _onInferenceComplete: Callback      │  result notify
│                                         │
│ METHODS:                                │
│  - loadModel()                         │  load .tflite
│    └─ Input shape: [1, 187]           │
│    └─ Output shape: [1, 1] (prob)     │
│                                         │
│  - runInference(List<double>)          │
│    └─ Check length == 187              │
│    └─ Reshape to [1, 187]              │
│    └─ Execute interpreter              │
│    └─ Parse output (0.0-1.0 prob)      │
│    └─ Threshold > 0.5                  │
│    └─ Calculate confidence %           │
│    └─ Return result dict               │
│                                         │
│  - close()                             │  cleanup
│  - _printModelInfo()                   │  debug
│                                         │
│ RESULT FORMAT:                          │
│ {                                       │
│   'label': 'NORMAL' | 'ARRHYTHMIA'    │
│   'isArrhythmia': bool                 │
│   'confidence': double (0-100)         │
│   'rawOutput': double (0.0-1.0)        │
│   'color': 'green' | 'red'             │
│ }                                       │
└─────────────────────────────────────────┘
```

**Performance**:
- Load: ~500ms
- Inference: ~50-100ms
- Memory: ~2-5MB

### 3. BluetoothService

**Responsibility**: BLE device communication

```
┌─────────────────────────────────────────────┐
│  BluetoothService                           │
├─────────────────────────────────────────────┤
│ PROPERTIES:                                 │
│  - _flutterBlue: FlutterBluePlus          │
│  - _connectedDevice: BluetoothDevice      │
│  - _isScanning: bool                      │
│  - _connectionState: enum                 │
│  - _services: List<BluetoothService>      │
│                                             │
│ CALLBACKS:                                  │
│  - onDeviceFound(device)                  │
│  - onConnectionState(state)               │
│  - onDataReceived(data)                   │
│                                             │
│ METHODS:                                    │
│  - checkBluetoothAvailable()              │
│  - startScan()                            │  5 sec scan
│  - stopScan()                             │  stop scan
│  - connectToDevice(device)                │  establish conn
│  - discoverServices()                     │  find GATT
│  - sendPredictionResult(label, conf)     │  core tx
│  - enableNotifications(char)              │  listen
│  - disconnect()                           │  close conn
│                                             │
│ MESSAGE FORMAT:                             │
│  "NORMAL|92.50"                           │  UTF-8 string
│  "ARRHYTHMIA|87.33"                       │
└─────────────────────────────────────────────┘
```

**BLE Protocol**:
- Scan Duration: 5 sec
- Connection Type: Central (app → device)
- Service Discovery: GATT
- Send: Write characteristic (BLE notify)
- Receive: Notification listener

---

## 📱 UI Component Hierarchy

```
MaterialApp
 │
 ├── route: '/'
 │   └── HomeScreen (StatefulWidget)
 │       ├── AppBar
 │       │   ├── Title: "💓 Real-Time ECG Monitor"
 │       │   └── Actions
 │       │       └── Bluetooth Button
 │       │
 │       └── Body
 │           ├── _buildStatusBanner()
 │           │   ├── Monitoring Indicator
 │           │   ├── Status Text
 │           │   └── Buffer Progress
 │           │
 │           ├── Padding: ECG Waveform Section
 │           │   ├── Title
 │           │   └── ECGGraphWidget (fl_chart)
 │           │       ├── LineChart
 │           │       ├── Grid
 │           │       ├── Axes
 │           │       └── Touch Tooltips
 │           │
 │           ├── ResultCard (if result exists)
 │           │   ├── Icon Indicator
 │           │   ├── Label (NORMAL/ARRHYTHMIA)
 │           │   ├── Status Text
 │           │   ├── Confidence Bar
 │           │   └── Raw Probability
 │           │
 │           ├── _buildMonitoringStats()
 │           │   ├── Total Scans Card
 │           │   ├── Buffer Fill Card
 │           │   └── Data Points Card
 │           │
 │           ├── _buildControlButtons()
 │           │   ├── START/STOP Button
 │           │   └── RESET Button
 │           │
 │           └── _buildPredictionHistory()
 │               └── ListView<Prediction>
 │                   ├── Icon (warning/heart)
 │                   ├── Label
 │                   ├── Confidence %
 │                   └── Timestamp
 │
 └── route: '/watch'
     └── WatchScreen (StatefulWidget)
         ├── AppBar
         ├── Body
         │   ├── _buildConnectionStatus()
         │   ├── _buildStatusDisplay()
         │   │   ├── Emoji (💚/⚠️)
         │   │   ├── Label (NORMAL/ARRHYTHMIA)
         │   │   └── Confidence
         │   ├── MinimalECGGraph
         │   └── _buildHistory()
```

---

## 🔌 State Management Pattern

### HomeScreen State

```dart
class _HomeScreenState extends State<HomeScreen> {
  // Services (singletons)
  late TFLiteService _tfliteService;
  late ECGStreamingService _streamingService;
  late BluetoothService _bluetoothService;

  // UI State
  bool _isModelLoading = true;
  bool _isMonitoring = false;
  String _lastPrediction = '';
  double _lastConfidence = 0.0;

  // Data State
  List<double> _ecgBuffer = [];
  List<double> _displayData = [];
  int _inferenceCount = 0;
  List<Map> _predictionHistory = [];
}
```

**State Flow**:
```
Initialization
    ↓
_initializeServices() async
    ├─ loadModel()
    ├─ initialize() ECG
    ├─ setUp callbacks
    └─ setState(_isModelLoading=false)
    
Ready State
    ├─ _isMonitoring=false
    ├─ _ecgBuffer=[]
    └─ Display: "○ Stopped"

User clicks START
    ↓
_toggleMonitoring()
    ├─ setState(_isMonitoring=true)
    └─ _streamingService.startStreaming()

Streaming State
    ├─ Timer ticks every 50ms
    ├─ Calls onDataUpdate callback
    ├─ setState updates _displayData
    ├─ Graph re-renders
    └─ Display: "● Live Monitoring..."

Buffer Full (after ~9 sec)
    ↓
onInferenceReady callback
    └─ _runInference(buffer)
        ├─ TFLite inference
        ├─ Parse result
        ├─ setState updates _lastPrediction
        ├─ setState adds to _predictionHistory
        ├─ Send Bluetooth (if connected)
        ├─ UI updates ResultCard
        └─ Loop continues
```

---

## 🎯 Callback Chain

```
ECGStreamingService
    │
    ├── onDataUpdate(buffer, latestValue)
    │   └─ Called every 50ms
    │      └─ HomeScreen setState
    │         ├─ Update _displayData
    │         └─ Rebuild Graph
    │
    └── onInferenceReady(fullBuffer)
        └─ Called when buffer[187] full
           └─ HomeScreen._runInference()
              ├─ TFLiteService.runInference()
              ├─ Parse result
              ├─ setState(result)
              ├─ BluetoothService.sendPredictionResult()
              └─ _updateUI()
```

---

## 📊 Timing Diagram

```
Time(ms)   Event                    ECGStream   Buffer      Inference
┌──────────────────────────────────┐
│ 0        START button              STOP→START  []          -
│ 50       1st data point            v0 added    [1]         -
│ 100      2nd data point            v1 added    [2]         -
│ ...
│ 9300     187th data point          v186 added  [187] FULL  Running...
│ 9350     Inference result ready    -           FULL        Result→ 
│ 9400     UI update (Result Card)   -           FULL        Complete
│ 9450     Buffer clears             -           []          -
│ 9500     1st data point (loop)     v187 added  [1]         -
│ ...
└──────────────────────────────────┘
```

---

## 🔐 Error Handling

```
Initialization
  ├─ Model not found ✗ → Try synthetic
  ├─ CSV missing ✗ → Generate synthetic
  └─ Services init fail ✗ → Show dialog

Runtime
  ├─ Buffer size mismatch ✗ → Skip inference
  ├─ Inference timeout ✗ → Log + continue
  ├─ BLE send fail ✗ → Log + UI shows "disconnected"
  └─ CSV normalization fail ✗ → Use defaults
```

---

## 📈 Performance Metrics

### Latency
- CSV Load: ~100ms
- Model Load: ~500ms
- Inference: ~50-100ms
- Bluetooth Send: ~50-200ms
- UI Redraw: ~16ms (60 FPS)

### Memory
- Model: ~2-5 MB
- ECG Buffer: ~1.5 KB (187×8 bytes)
- CSV (5000 points): ~40 KB
- UI Widgets: ~1-2 MB

### CPU
- Streaming: ~5-10% (timer + buffer)
- Inference: ~30-50% (TFLite)
- Total: ~35-60%

---

## 🔬 Testing Architecture

```
Unit Tests (services)
├── ECGStreamingService
│   ├── testNormalization()
│   ├── testBufferFilling()
│   └── testCallbackTiming()
│
├── TFLiteService
│   ├── testModelLoad()
│   ├── testInferenceShape()
│   └── testConfidenceCalculation()
│
└── BluetoothService
    ├── testDeviceDiscovery()
    ├── testMessageFormat()
    └── testDisconnection()

Integration Tests (flows)
├── testStartStop()
├── testFullCycle()
└── testArrhythmiaAlert()

Widget Tests (UI)
├── testGraphRendering()
├── testResultCardDisplay()
└── testHistoryUpdate()
```

---

## 🚀 Deployment Flow

```
Development Build
    ├─ flutter run
    ├─ Emulator/real device
    └─ Debug logs enabled

Release Build
    ├─ flutter build apk (Android)
    ├─ flutter build ios (iOS)
    ├─ Sign with certificate
    ├─ Test on real device
    └─ Remove debug logs

Production
    ├─ Upload to Play Store / App Store
    ├─ Monitor crash logs
    ├─ Version control
    └─ Regular updates
```

---

**Architecture designed for maintainability, testability, and real-time performance. 🎯**
