import 'package:tflite_flutter/tflite_flutter.dart';

/// Callback for inference results
typedef InferenceCallback = void Function(Map<String, dynamic> result);

/// Service for TFLite model inference
/// Handles loading the ECG classification model and running predictions
class TFLiteService {
  static final TFLiteService _instance = TFLiteService._internal();

  /// Private constructor for singleton pattern
  TFLiteService._internal();

  /// Factory constructor
  factory TFLiteService() {
    return _instance;
  }

  /// TFLite interpreter
  Interpreter? _interpreter;

  /// Model loaded flag
  bool _isModelLoaded = false;

  /// Inference callback
  InferenceCallback? _onInferenceComplete;

  /// Get model loaded status
  bool get isModelLoaded => _isModelLoaded;

  /// Get interpreter instance
  Interpreter? get interpreter => _interpreter;

  /// Register inference callback
  void onInferenceComplete(InferenceCallback callback) {
    _onInferenceComplete = callback;
  }

  /// Load the TFLite model
  /// Loads the model from assets and initializes the interpreter
  Future<bool> loadModel() async {
    try {
      if (_interpreter != null) {
        print('✓ Model already loaded');
        return true;
      }

      print('📦 Loading TFLite model...');
      
      // Load model from assets
      _interpreter = await Interpreter.fromAsset('assets/mamba_ecg.tflite');
      
      _isModelLoaded = true;
      print('Model loaded successfully');
      
      // Print model info
      _printModelInfo();
      
      return true;
    } catch (e) {
      print('Error loading model: $e');
      _isModelLoaded = false;
      return false;
    }
  }

  /// Print model input/output information
  void _printModelInfo() {
    if (_interpreter == null) return;

    print('\n📊 Model Information:');
    print('   Input Tensors: ${_interpreter!.getInputTensors().length}');
    print('   Output Tensors: ${_interpreter!.getOutputTensors().length}');

    for (var tensor in _interpreter!.getInputTensors()) {
      print('   Input Shape: ${tensor.shape}');
      print('   Input Type: ${tensor.type}');
    }

    for (var tensor in _interpreter!.getOutputTensors()) {
      print('   Output Shape: ${tensor.shape}');
      print('   Output Type: ${tensor.type}');
    }
  }

  /// Run inference on ECG data
  /// 
  /// Parameters:
  /// - input: List of 187 ECG values (normalized)
  /// 
  /// Returns: Classification result (0 = Normal, 1 = Arrhythmia)
  Future<Map<String, dynamic>> runInference(List<double> input) async {
    try {
      if (!_isModelLoaded || _interpreter == null) {
        throw Exception('Model not loaded. Call loadModel() first.');
      }

      if (input.length != 187) {
        throw Exception('Input length must be 187, got ${input.length}');
      }

      print('🔄 Running inference...');

      // Prepare input: reshape to [1, 187]
      final inputList = [input];

      // Prepare output tensor
      final outputShape = _interpreter!.getOutputTensors()[0].shape;
      final outputTensor = List.filled(outputShape.reduce((a, b) => a * b), 0.0);

      // Run inference
      _interpreter!.run(inputList, [outputTensor]);

      // Parse results
      final probability = outputTensor[0];
      final isArrhythmia = probability > 0.5;
      final confidence = (isArrhythmia ? probability : 1.0 - probability) * 100;

      print('✅ Inference complete');
      print('   Prediction: ${isArrhythmia ? "ARRHYTHMIA ⚠️" : "NORMAL ✓"}');
      print('   Confidence: ${confidence.toStringAsFixed(2)}%');

      final result = {
        'isArrhythmia': isArrhythmia,
        'rawOutput': probability,
        'confidence': confidence,
        'label': isArrhythmia ? 'ARRHYTHMIA' : 'NORMAL',
        'color': isArrhythmia ? 'red' : 'green',
      };

      // Call callback if registered
      _onInferenceComplete?.call(result);

      return result;
    } catch (e) {
      print('❌ Inference error: $e');
      rethrow;
    }
  }

  /// Close the interpreter and free resources
  Future<void> close() async {
    try {
      if (_interpreter != null) {
        _interpreter!.close();
        _interpreter = null;
        _isModelLoaded = false;
        print('🔌 Model closed');
      }
    } catch (e) {
      print('❌ Error closing model: $e');
    }
  }
}
