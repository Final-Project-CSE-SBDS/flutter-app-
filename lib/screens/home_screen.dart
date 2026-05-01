import 'package:flutter/material.dart';
import '../services/tflite_service.dart';
import '../services/ecg_streaming_service.dart';
import '../services/bluetooth_service.dart';
import '../services/notification_service.dart';
import '../services/csv_service.dart';
import 'bluetooth_screen.dart';
import '../widgets/ecg_graph.dart';
import '../widgets/result_card.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Services
  late TFLiteService _tfliteService;
  late ECGStreamingService _streamingService;
  late BluetoothService _bluetoothService;
  late NotificationService _notificationService;
  late CSVService _csvService;


  bool _isModelLoading = true;
  bool _isMonitoring = false;
  bool _showArrhythmiaAlert = false;
  String _lastPrediction = '';
  double _lastConfidence = 0.0;

  /// CSV Loading State
  bool _isLoadingCSV = false;
  String _csvStatusMessage = '';
  bool _hasCustomCSV = false;

  /// Bluetooth State
  fbp.BluetoothConnectionState _bluetoothConnectionState =
      fbp.BluetoothConnectionState.disconnected;
  fbp.BluetoothDevice? _connectedDevice;
  
  /// ECG Data
  List<double> _ecgBuffer = [];
  List<double> _displayData = [];
  int _inferenceCount = 0;

  /// Inference History
  List<Map<String, dynamic>> _predictionHistory = [];

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  /// Initialize all services
  Future<void> _initializeServices() async {
    try {
      _tfliteService = TFLiteService();
      _streamingService = ECGStreamingService();
      _bluetoothService = BluetoothService();
      _notificationService = NotificationService();
      _csvService = CSVService();

      print('📦 Initializing services...');

      // Load model
      bool modelLoaded = await _tfliteService.loadModel();
      if (!modelLoaded) {
        throw Exception('Failed to load TFLite model');
      }

      // Initialize ECG streaming
      await _streamingService.initialize();

  
      setState(() {
        _hasCustomCSV = _streamingService.hasCustomData;
        _csvStatusMessage = _hasCustomCSV
            ? 'Custom CSV loaded (${_streamingService.currentDataPoints} points)'
            : 'Using pre-recorded ECG data';
      });

      // Set up Bluetooth callbacks
      _bluetoothService.onConnectionState((state) {
        setState(() {
          _bluetoothConnectionState = state;
          _connectedDevice = _bluetoothService.connectedDevice;
        });
      });

      // Set up ECG streaming callbacks
      _streamingService.onDataUpdate((buffer, latestValue) {
        setState(() {
          _ecgBuffer = buffer;
          _displayData = List.from(buffer);
        });
      });

      _streamingService.onInferenceReady((buffer) {
        _runInference(buffer);
      });

      setState(() => _isModelLoading = false);
      print(' Services initialized');
    } catch (e) {
      print(' Initialization error: $e');
      if (mounted) {
        _showErrorDialog('Initialization Error: ${e.toString()}');
      }
    }
  }

  /// Run inference on ECG buffer
  Future<void> _runInference(List<double> buffer) async {
    if (buffer.length != 187) return;

    try {
      final result = await _tfliteService.runInference(buffer);

      setState(() {
        _inferenceCount++;
        _lastPrediction = result['label'];
        _lastConfidence = result['confidence'];
        _showArrhythmiaAlert = result['isArrhythmia'];

        // Add to history
        _predictionHistory.insert(0, {
          'label': result['label'],
          'confidence': result['confidence'],
          'timestamp': DateTime.now(),
        });

        // Keep last 20 predictions
        if (_predictionHistory.length > 20) {
          _predictionHistory.removeLast();
        }
      });

      // Format confidence for notification
      final confidenceText = 'Confidence: ${result['confidence'].toStringAsFixed(2)}%';

      // Debug: Log inference result
      print('🧠 Inference Result:');
      print('   Label: ${result['label']}');
      print('   Confidence: ${result['confidence'].toStringAsFixed(2)}%');
      print('   Is Arrhythmia: ${result['isArrhythmia']}');

      // Send notification based on prediction
      print('📬 Triggering notification service...');
      if (result['isArrhythmia']) {
        print('   → Sending ARRHYTHMIA alert');
        await _notificationService.showArrhythmiaAlert(
          confidence: confidenceText,
          enableVibration: true,
          enableSound: true,
        );
      } else {
        print('   → Sending NORMAL result');
        await _notificationService.showNormalResult(
          confidence: confidenceText,
        );
      }

      // Send result via Bluetooth if connected
      if (_bluetoothService.isConnected) {
        print('📡 Bluetooth connected - sending prediction...');
        await _bluetoothService.sendPredictionResult(
          label: result['label'],
          confidence: result['confidence'],
          includeConfidence: true,
        );
      } else {
        print('📡 Bluetooth not connected - skipping BLE send');
      }

      // Show alert on arrhythmia
      if (result['isArrhythmia'] && !_showArrhythmiaAlert) {
        _showArrhythmiaDialog(result['confidence']);
      }
    } catch (e) {
      print('❌ Inference error: $e');
    }
  }

  /// Show arrhythmia alert dialog
  void _showArrhythmiaDialog(double confidence) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('⚠️ Arrhythmia Alert'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Abnormal heart rhythm detected!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Confidence: ${confidence.toStringAsFixed(2)}%',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please seek medical attention if symptoms persist.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Start/Stop monitoring
  void _toggleMonitoring() {
    setState(() {
      if (_isMonitoring) {
        _streamingService.stopStreaming();
        _isMonitoring = false;
        print('⏹️  Monitoring stopped');
      } else {
        _streamingService.startStreaming();
        _isMonitoring = true;
        print('▶️  Monitoring started');
      }
    });
  }

  /// Reset monitoring
  void _resetMonitoring() {
    _streamingService.reset();
    setState(() {
      _ecgBuffer.clear();
      _displayData.clear();
      _lastPrediction = '';
      _lastConfidence = 0.0;
      _showArrhythmiaAlert = false;
      _inferenceCount = 0;
      _predictionHistory.clear();
    });
    _showSnackbar('Monitoring reset');
  }

  /// Load custom CSV file
  Future<void> _loadCustomCSV() async {
    setState(() {
      _isLoadingCSV = true;
      _csvStatusMessage = 'Selecting CSV file...';
    });

    try {
      bool success = await _streamingService.loadCustomCSV();

      if (success) {
        setState(() {
          _hasCustomCSV = true;
          _csvStatusMessage = 'Custom CSV loaded (${_streamingService.currentDataPoints} points)';
        });
        _showSnackbar('Custom CSV loaded successfully!');
      } else {
        setState(() {
          _csvStatusMessage = 'Using sample ECG data';
        });
        _showSnackbar('No CSV file selected');
      }
    } catch (e) {
      setState(() {
        _csvStatusMessage = 'Error loading CSV: ${e.toString()}';
      });
      _showErrorDialog('CSV Loading Error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoadingCSV = false;
      });
    }
  }

  /// Reset to sample ECG data
  Future<void> _resetToSampleData() async {
    setState(() {
      _isLoadingCSV = true;
      _csvStatusMessage = 'Resetting to sample data...';
    });

    try {
      await _streamingService.resetToSampleData();

      setState(() {
        _hasCustomCSV = false;
        _csvStatusMessage = 'Using sample ECG data';
      });

      _showSnackbar('Reset to sample ECG data');
    } catch (e) {
      _showErrorDialog('Error resetting to sample data: ${e.toString()}');
    } finally {
      setState(() {
        _isLoadingCSV = false;
      });
    }
  }

  /// Connect to Bluetooth device
  void _connectBluetooth() {
    if (!mounted) return;

    // Navigate to Bluetooth screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BluetoothScreen(
          bluetoothService: _bluetoothService,
        ),
      ),
    );
  }

  /// Show error dialog
  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Show snackbar
  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _streamingService.dispose();
    _bluetoothService.dispose();
    _tfliteService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: _isModelLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Initializing ECG System...'),
                  ],
                ),
              )
            : CustomScrollView(
                slivers: [
                  // Perfect Responsive Header
                  SliverToBoxAdapter(
                    child: _buildPerfectHeader(),
                  ),

                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        // Status Card
                        _buildStatusCard(),

                        // ECG Graph Card
                        _buildECGGraphCard(),

                        // Result Card
                        if (_lastPrediction.isNotEmpty) _buildResultCard(),

                        // Stats Cards
                        _buildStatsSection(),

                        // Control Section
                        _buildControlSection(),

                        // History Section
                        if (_predictionHistory.isNotEmpty)
                          _buildHistorySection(),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Build connection status badge
  Widget _buildConnectionBadge() {
    bool isConnected =
        _bluetoothConnectionState == fbp.BluetoothConnectionState.connected;

    return GestureDetector(
      onTap: _connectBluetooth,
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isConnected
              ? Colors.green.withOpacity(0.2)
              : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isConnected ? Colors.green : Colors.white30,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              isConnected ? 'Connected' : 'Connect',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build Perfect Responsive Header
  Widget _buildPerfectHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.indigo.shade800,
            Colors.indigo.shade600,
            Colors.purple.shade600,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Logo - Perfect Centered with local image
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.4),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: Image.asset(
                  'assets/icon.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback to icon if image fails
                    return const Icon(
                      Icons.monitor_heart,
                      color: Colors.white,
                      size: 52,
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Title - Perfect Centered
            const Text(
              'ECG monitor',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1.0,
                height: 1.2,
              ),
            ),

            const SizedBox(height: 24),

            // Status Row - Perfect Centered with Bluetooth
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Monitoring Status
                  Expanded(
                    child: _buildStatusPill(
                      icon: _isMonitoring ? Icons.favorite : Icons.favorite_border,
                      label: _isMonitoring ? 'Monitoring' : 'Standby',
                      color: _isMonitoring ? Colors.greenAccent : Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Bluetooth Status - Tappable
                  Expanded(
                    child: GestureDetector(
                      onTap: _connectBluetooth,
                      child: _buildStatusPill(
                        icon: _bluetoothConnectionState == fbp.BluetoothConnectionState.connected
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth,
                        label: _bluetoothConnectionState == fbp.BluetoothConnectionState.connected
                            ? 'Connected'
                            : 'Tap to Connect',
                        color: _bluetoothConnectionState == fbp.BluetoothConnectionState.connected
                            ? Colors.cyanAccent
                            : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Bottom decorative line
            Container(
              width: 60,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 24),

            // Bottom Curve
            Container(
              height: 35,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build status pill
  Widget _buildStatusPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: color.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Build status card
  Widget _buildStatusCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isMonitoring
                ? [Colors.green.shade400, Colors.green.shade600]
                : [Colors.grey.shade400, Colors.grey.shade600],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (_isMonitoring ? Colors.green : Colors.grey)
                  .withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Status Indicator
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isMonitoring ? Icons.monitor_heart : Icons.monitor_heart_outlined,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            // Status Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isMonitoring ? 'Live Monitoring' : 'Ready to Monitor',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isMonitoring
                        ? 'Analyzing ECG data in real-time'
                        : 'Press START to begin analysis',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            // Live Indicator
            if (_isMonitoring)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build ECG Graph Card
  Widget _buildECGGraphCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.05),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.show_chart,
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'ECG Waveform',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Data source badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _hasCustomCSV
                          ? Colors.green.withOpacity(0.1)
                          : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _hasCustomCSV
                              ? Icons.file_present
                              : Icons.data_array,
                          size: 12,
                          color:
                              _hasCustomCSV ? Colors.green : Colors.blue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _hasCustomCSV ? 'Custom' : 'Sample',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color:
                                _hasCustomCSV ? Colors.green : Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Graph
            Container(
              height: 220,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ECGGraphWidget(
                  ecgData: _displayData,
                  lineColor:
                      _showArrhythmiaAlert ? Colors.red : Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build Result Card
  Widget _buildResultCard() {
    bool isArrhythmia = _lastPrediction == 'ARRHYTHMIA';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isArrhythmia
                ? [Colors.red.shade400, Colors.red.shade600]
                : [Colors.green.shade400, Colors.green.shade600],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (isArrhythmia ? Colors.red : Colors.green)
                  .withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isArrhythmia ? Icons.warning_amber : Icons.check_circle,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _lastPrediction,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Confidence: ${_lastConfidence.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Confidence Circle
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _lastConfidence / 100,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 4,
                  ),
                  Text(
                    '${_lastConfidence.toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build Stats Section
  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              title: 'Total Scans',
              value: '$_inferenceCount',
              icon: Icons.analytics,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              title: 'Buffer',
              value: '${_streamingService.bufferFilledPercentage}%',
              icon: Icons.storage,
              color: Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              title: 'Data Points',
              value: '${_streamingService.currentDataPoints}',
              icon: Icons.data_usage,
              color: Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  /// Build individual stat card
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  /// Build Control Section
  Widget _buildControlSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.control_point,
                    color: Colors.indigo,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Controls',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // CSV Control
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    _hasCustomCSV ? Icons.file_present : Icons.file_copy,
                    color: _hasCustomCSV ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _csvStatusMessage,
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            _hasCustomCSV ? Colors.green.shade700 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                // Start/Stop Button
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _toggleMonitoring,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor:
                          _isMonitoring ? Colors.red : Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isMonitoring ? Icons.stop : Icons.play_arrow,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isMonitoring ? 'STOP' : 'START',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Reset Button
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resetMonitoring,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.refresh, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          'RESET',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // CSV Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoadingCSV ? null : _loadCustomCSV,
                    icon: _isLoadingCSV
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.upload_file, size: 18),
                    label: const Text('Upload CSV'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                if (_hasCustomCSV) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoadingCSV ? null : _resetToSampleData,
                      icon: const Icon(Icons.restore, size: 18),
                      label: const Text('Sample Data'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build History Section
  Widget _buildHistorySection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.05),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.history,
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Recent Predictions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // History List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _predictionHistory.length > 5
                  ? 5
                  : _predictionHistory.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: Colors.grey.shade200,
              ),
              itemBuilder: (context, index) {
                final pred = _predictionHistory[index];
                bool isArrhythmia = pred['label'] == 'ARRHYTHMIA';
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (isArrhythmia ? Colors.red : Colors.green)
                          .withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isArrhythmia ? Icons.warning : Icons.favorite,
                      color: isArrhythmia ? Colors.red : Colors.green,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    pred['label'],
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isArrhythmia ? Colors.red : Colors.green.shade700,
                    ),
                  ),
                  subtitle: Text(
                    '${pred['confidence'].toStringAsFixed(1)}% • ${_formatTime(pred['timestamp'])}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade400,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}

/// Custom painter for ECG pattern background
class _ECGPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw ECG-like wave pattern
    final path = Path();
    double y = size.height * 0.6;
    double x = 0;

    while (x < size.width) {
      // P wave
      path.moveTo(x, y);
      path.quadraticBezierTo(x + 10, y - 5, x + 20, y);
      x += 20;

      // QRS complex
      path.moveTo(x, y);
      path.lineTo(x + 5, y);
      path.lineTo(x + 8, y + 20); // Q
      path.lineTo(x + 12, y - 30); // R
      path.lineTo(x + 16, y + 15); // S
      path.lineTo(x + 20, y);
      x += 20;

      // T wave
      path.moveTo(x, y);
      path.quadraticBezierTo(x + 10, y - 8, x + 20, y);
      x += 20;

      // Baseline
      path.moveTo(x, y);
      path.lineTo(x + 30, y);
      x += 30;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}