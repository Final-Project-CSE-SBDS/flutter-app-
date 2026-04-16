import 'dart:math';
import 'package:flutter/material.dart';
import '../services/tflite_service.dart';
import '../widgets/result_card.dart';

/// Home screen of the ECG Monitor application
/// Handles ECG data input, model inference, and result display
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// TFLite service instance
  late TFLiteService _tfliteService;

  /// Current ECG data (187 values)
  List<double>? _ecgData;

  /// Inference result
  Map<String, dynamic>? _result;

  /// Loading states
  bool _isModelLoading = false;
  bool _isInferencing = false;

  /// Lifecycle callbacks
  @override
  void initState() {
    super.initState();
    _tfliteService = TFLiteService();
    _initializeModel();
  }

  @override
  void dispose() {
    _tfliteService.close();
    super.dispose();
  }

  /// Initialize the TFLite model
  Future<void> _initializeModel() async {
    setState(() => _isModelLoading = true);
    try {
      final success = await _tfliteService.loadModel();
      if (!success) {
        _showErrorDialog('Failed to load TFLite model');
      }
    } catch (e) {
      _showErrorDialog('Error: ${e.toString()}');
    } finally {
      setState(() => _isModelLoading = false);
    }
  }

  /// Generate random ECG-like signal (187 values)
  /// Simulates a typical ECG waveform with normal characteristics
  void _generateSampleECG() {
    print('\n🔄 Generating sample ECG data...');
    
    const int length = 187;
    final random = Random();
    final ecgData = <double>[];

    /// Generate realistic ECG-like signal using sine waves
    for (int i = 0; i < length; i++) {
      /// Base signal: combination of multiple frequencies
      double t = i / length * 4 * pi;
      
      /// Main ECG component
      double mainSignal = sin(t) * 0.5;
      
      /// Add harmonic content
      mainSignal += sin(2 * t) * 0.3;
      mainSignal += sin(0.5 * t) * 0.2;
      
      /// Add noise
      double noise = (random.nextDouble() - 0.5) * 0.1;
      
      /// Normalize to reasonable range
      double value = (mainSignal + noise) * 0.5 + 0.5;
      
      /// Clamp between 0 and 1
      value = value.clamp(0.0, 1.0);
      
      ecgData.add(value);
    }

    setState(() => _ecgData = ecgData);
    print('✅ Sample ECG generated (${ecgData.length} values)');
    _showSnackbar('Sample ECG generated successfully!');
  }

  /// Load ECG data from CSV file
  /// Expected format: single column or comma-separated values
  Future<void> _loadECGFile() async {
    // File picker removed - use sample generation instead
    _showSnackbar('Use "Generate Sample ECG" to create test data');
  }


  /// Normalize ECG data to 0-1 range
  List<double> _normalizeECG(List<double> data) {
    if (data.isEmpty) return data;

    final min = data.reduce((a, b) => a < b ? a : b);
    final max = data.reduce((a, b) => a > b ? a : b);
    final range = max - min;

    if (range == 0) {
      return List.filled(data.length, 0.5);
    }

    return data.map((v) => (v - min) / range).toList();
  }

  /// Run inference on loaded ECG data
  Future<void> _runInference() async {
    if (_ecgData == null) {
      _showSnackbar('Please load or generate ECG data first');
      return;
    }

    setState(() => _isInferencing = true);

    try {
      print('\n🔍 Starting inference...');

      /// Normalize ECG data
      final normalized = _normalizeECG(_ecgData!);

      /// Run inference
      final result = await _tfliteService.runInference(normalized);

      setState(() => _result = result);

      /// Show alert if arrhythmia detected
      if (result['isArrhythmia'] as bool) {
        _showArrhythmiaAlert();
      }

      print('✅ Inference completed');
    } catch (e) {
      _showErrorDialog('Inference error: $e');
    } finally {
      setState(() => _isInferencing = false);
    }
  }

  /// Show alert dialog for arrhythmia detection
  void _showArrhythmiaAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Alert'),
        content: const Text(
          'Abnormal heartbeat detected!\n\nPlease consult a healthcare professional.',
        ),
        backgroundColor: const Color(0xFFFFEBEE),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show snackbar notification
  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ECG Monitor (Mamba AI)'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              /// Header section
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.favorite,
                        size: 48,
                        color: Color(0xFF1E88E5),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Arrhythmia Detection',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isModelLoading
                            ? 'Loading model...'
                            : _tfliteService.isModelLoaded
                                ? 'Model ready'
                                : 'Model failed to load',
                        style: TextStyle(
                          fontSize: 14,
                          color: _tfliteService.isModelLoaded
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              /// ECG Data Input Section
              Text(
                'Step 1: Generate ECG Data',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),

              /// Generate sample button
              ElevatedButton.icon(
                onPressed: _generateSampleECG,
                icon: const Icon(Icons.refresh),
                label: const Text('Generate Sample ECG'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF1976D2),
                ),
              ),

              /// Data loaded indicator
              if (_ecgData != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF4CAF50)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Color(0xFF4CAF50)),
                        const SizedBox(width: 12),
                        Text(
                          'ECG Data Loaded: ${_ecgData!.length} values',
                          style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 32),

              /// Analysis Section
              Text(
                'Step 2: Run Analysis',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),

              /// Analyze button
              ElevatedButton.icon(
                onPressed: _isInferencing || _ecgData == null
                    ? null
                    : _runInference,
                icon: _isInferencing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(_isInferencing ? 'Analyzing...' : 'Analyze'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(height: 32),

              /// Results Section
              if (_result != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analysis Result',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    ResultCard(
                      label: _result!['label'],
                      rawOutput: _result!['rawOutput'],
                      confidence: _result!['confidence'],
                      isArrhythmia: _result!['isArrhythmia'],
                      onAcknowledge: () => setState(() => _result = null),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
