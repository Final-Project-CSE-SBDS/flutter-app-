import 'package:flutter/material.dart';
import '../services/tflite_service.dart';
import '../services/ecg_streaming_service.dart';
import '../services/bluetooth_service.dart';
import '../widgets/ecg_graph.dart';
import '../widgets/result_card.dart';

/// Home Screen - Real-time ECG Monitoring
/// Main monitoring interface with live ECG graph and predictions
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

  /// UI State
  bool _isModelLoading = true;
  bool _isMonitoring = false;
  bool _showArrhythmiaAlert = false;
  String _lastPrediction = '';
  double _lastConfidence = 0.0;
  
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

      print('📦 Initializing services...');

      // Load model
      bool modelLoaded = await _tfliteService.loadModel();
      if (!modelLoaded) {
        throw Exception('Failed to load TFLite model');
      }

      // Initialize ECG streaming
      await _streamingService.initialize();

      // Set up callbacks
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
      print('✅ Services initialized');
    } catch (e) {
      print('❌ Initialization error: $e');
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

      // Send result via Bluetooth if connected
      if (_bluetoothService.isConnected) {
        await _bluetoothService.sendPredictionResult(
          result['label'],
          result['confidence'],
        );
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

  /// Connect to Bluetooth device
  void _connectBluetooth() async {
    if (!mounted) return;

    // Show connection dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bluetooth Connection'),
        content: const Text('In production, this would scan for available devices. '
            'The system is ready to send ECG predictions via Bluetooth.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
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
      appBar: AppBar(
        title: const Text('💓 Real-Time ECG Monitor'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth),
            onPressed: _connectBluetooth,
            tooltip: 'Connect Bluetooth',
          ),
        ],
      ),
      body: _isModelLoading
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
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Status Banner
                  _buildStatusBanner(),

                  // ECG Graph
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Live ECG Waveform',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 250,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white,
                          ),
                          child: ECGGraphWidget(
                            ecgData: _displayData,
                            lineColor: _showArrhythmiaAlert
                                ? Colors.red
                                : Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Latest Result
                  if (_lastPrediction.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ResultCard(
                        label: _lastPrediction,
                        rawOutput: _lastConfidence / 100,
                        confidence: _lastConfidence,
                        isArrhythmia: _lastPrediction == 'ARRHYTHMIA',
                      ),
                    ),
                  ],

                  // Monitoring Stats
                  _buildMonitoringStats(),

                  // Control Buttons
                  _buildControlButtons(),

                  // Prediction History
                  if (_predictionHistory.isNotEmpty)
                    _buildPredictionHistory(),

                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  /// Build status banner
  Widget _buildStatusBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: _isMonitoring
          ? Colors.green.withOpacity(0.1)
          : Colors.grey.withOpacity(0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 8,
                backgroundColor:
                    _isMonitoring ? Colors.green : Colors.grey,
                child: _isMonitoring
                    ? const SizedBox(
                        width: 8,
                        height: 8,
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                _isMonitoring ? '● Live Monitoring...' : '○ Stopped',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _isMonitoring ? Colors.green : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _streamingService.isStreaming
                ? 'Buffer: ${_streamingService.bufferFilledPercentage}% | Inferences: $_inferenceCount'
                : 'Ready to monitor',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  /// Build monitoring stats
  Widget _buildMonitoringStats() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              title: 'Total Scans',
              value: '$_inferenceCount',
              icon: Icons.assessment,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              title: 'Buffer Fill',
              value: '${_streamingService.bufferFilledPercentage}%',
              icon: Icons.storage,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              title: 'Data Points',
              value: '${_streamingService.currentDataPoints}',
              icon: Icons.data_usage,
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
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// Build control buttons
  Widget _buildControlButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _toggleMonitoring,
              icon: Icon(_isMonitoring ? Icons.pause : Icons.play_arrow),
              label: Text(_isMonitoring ? 'STOP' : 'START'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor:
                    _isMonitoring ? Colors.red : Colors.green,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _resetMonitoring,
              icon: const Icon(Icons.refresh),
              label: const Text('RESET'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build prediction history
  Widget _buildPredictionHistory() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Predictions',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _predictionHistory.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final pred = _predictionHistory[index];
                bool isArrhythmia = pred['label'] == 'ARRHYTHMIA';
                return ListTile(
                  leading: Icon(
                    isArrhythmia ? Icons.warning : Icons.favorite,
                    color: isArrhythmia ? Colors.red : Colors.green,
                  ),
                  title: Text(pred['label']),
                  subtitle: Text(
                      '${pred['confidence'].toStringAsFixed(1)}% at ${_formatTime(pred['timestamp'])}'),
                  dense: true,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Format time
  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}