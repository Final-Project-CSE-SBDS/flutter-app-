import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

typedef InferenceCallback = void Function(Map<String, dynamic> result);

class TFLiteService {
  static final TFLiteService _instance = TFLiteService._internal();

  TFLiteService._internal();

  factory TFLiteService() {
    return _instance;
  }

  Interpreter? _interpreter;
  bool _isModelLoaded = false;
  InferenceCallback? _onInferenceComplete;

  bool get isModelLoaded => _isModelLoaded;

  void onInferenceComplete(InferenceCallback callback) {
    _onInferenceComplete = callback;
  }

  /// 🔥 IMPORTANT: full asset path for verification
  static const String _assetPath = 'assets/mamba_ecg.tflite';

  /// 🔥 IMPORTANT: filename only for interpreter
  static const String _modelName = 'mamba_ecg.tflite';

  // Expected input length for the model
  static const int _expectedInputLength = 187;

  Future<bool> loadModel() async {
    try {
      if (_interpreter != null) {
        print('✓ Model already loaded');
        return true;
      }

      print('🚀 Loading model...');

      /// 🔥 STEP 1: Verify asset exists
      final data = await rootBundle.load(_assetPath);
      print('✅ Asset verified: ${data.lengthInBytes} bytes for "$_assetPath"');

      // Try multiple load strategies and log fully so we can diagnose failures
      try {
        print('Attempting Interpreter.fromAsset with "$_modelName"');
        _interpreter = await Interpreter.fromAsset(_modelName);
        _isModelLoaded = true;
        print('🎉 Model loaded successfully via fromAsset("$_modelName")');
        _printModelInfo();
        return true;
      } catch (e1, st1) {
        print('fromAsset("$_modelName") failed: $e1');
        print(st1);

        try {
          print('Attempting Interpreter.fromAsset with "$_assetPath"');
          _interpreter = await Interpreter.fromAsset(_assetPath);
          _isModelLoaded = true;
          print('🎉 Model loaded successfully via fromAsset("$_assetPath")');
          _printModelInfo();
          return true;
        } catch (e2, st2) {
          print('fromAsset("$_assetPath") failed: $e2');
          print(st2);

          // Final fallback: load raw bytes and create interpreter from buffer
          try {
            print('Attempting Interpreter.fromBuffer using rootBundle bytes');
            final bytes = data.buffer.asUint8List();
            _interpreter = Interpreter.fromBuffer(bytes);
            _isModelLoaded = true;
            print('🎉 Model loaded successfully via Interpreter.fromBuffer(bytes)');
            _printModelInfo();
            return true;
          } catch (e3, st3) {
            print('Interpreter.fromBuffer failed: $e3');
            print(st3);
            rethrow;
          }
        }
      }
    } catch (e, st) {
      print('❌ MODEL LOAD ERROR: $e');
      print(st);
      _isModelLoaded = false;
      return false;
    }
  }

  void _printModelInfo() {
    if (_interpreter == null) return;

    print('\n📊 Model Info:');

    for (var t in _interpreter!.getInputTensors()) {
      print('Input Shape: ${t.shape}');
      print('Input Type: ${t.type}');
    }

    for (var t in _interpreter!.getOutputTensors()) {
      print('Output Shape: ${t.shape}');
      print('Output Type: ${t.type}');
    }
  }

  Future<Map<String, dynamic>> runInference(List<double> input) async {
    if (!_isModelLoaded || _interpreter == null) {
      throw Exception('Model not loaded');
    }

    // Ensure input length is sufficient; trim if longer than expected
    if (input.length < _expectedInputLength) {
      throw Exception('Input must be at least $_expectedInputLength values. Got ${input.length}');
    }

    List<double> usedInput = input;
    if (input.length > _expectedInputLength) {
      print('⚠️ Input length ${input.length} > $_expectedInputLength; trimming to $_expectedInputLength');
      usedInput = input.take(_expectedInputLength).toList();
    }

    print('🔄 Running inference on ${usedInput.length} values...');

    final inputTensor = [usedInput];
    final output = List.filled(1, 0.0).reshape([1, 1]);

    _interpreter!.run(inputTensor, output);

    final probability = output[0][0];
    final isArrhythmia = probability > 0.5;
    final confidence =
        (isArrhythmia ? probability : 1 - probability) * 100;

    final result = {
      'label': isArrhythmia ? 'ARRHYTHMIA' : 'NORMAL',
      'confidence': confidence,
      'raw': probability,
    };

    print('✅ Result: ${result['label']} (${confidence.toStringAsFixed(2)}%)');

    _onInferenceComplete?.call(result);

    return result;
  }

  Future<void> close() async {
    _interpreter?.close();
    _interpreter = null;
    _isModelLoaded = false;
    print('🔌 Model closed');
  }
}