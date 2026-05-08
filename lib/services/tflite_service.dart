import 'dart:math';
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

  static const String _assetPath = 'assets/mamba_ecg.tflite';
  static const String _modelName = 'mamba_ecg.tflite';
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

    // Build output container matching the model's output tensor shape
    final outputTensors = _interpreter!.getOutputTensors();
    if (outputTensors.isEmpty) {
      throw Exception('Model has no output tensors');
    }

    final outShape = outputTensors[0].shape; // e.g. [1,2]
    final outSize = outShape.reduce((a, b) => a * b);

    dynamic output;
    if (outShape.length == 1) {
      // 1D output
      output = List.filled(outShape[0], 0.0);
    } else if (outShape.length == 2) {
      output = List.generate(outShape[0], (_) => List.filled(outShape[1], 0.0));
    } else {
     
      output = List.filled(outSize, 0.0);
    }

    _interpreter!.run(inputTensor, output);

   
    double rawProb = 0.0;
    bool isArrhythmia = false;
    double confidence = 0.0;

    try {
      if (outSize == 1) {
        // Single scalar output
        if (outShape.length == 1) {
          rawProb = output[0];
        } else if (outShape.length == 2) {
          rawProb = output[0][0];
        } else {
          rawProb = output[0];
        }
        // Apply sigmoid to convert raw output to probability
        rawProb = 1 / (1 + exp(-rawProb));
        isArrhythmia = rawProb > 0.5;
        confidence = (isArrhythmia ? rawProb : 1.0 - rawProb) * 100.0;
      } else if (outSize == 2 && outShape.length == 2 && outShape[0] == 1) {
        // Two-class output: [1,2] - apply softmax
        final p0 = (output[0][0] as num).toDouble();
        final p1 = (output[0][1] as num).toDouble();
        // Softmax: exp(x) / sum(exp(xi))
        final exp0 = exp(p0);
        final exp1 = exp(p1);
        final softmax0 = exp0 / (exp0 + exp1);
        final softmax1 = exp1 / (exp0 + exp1);
        // Choose class with higher probability
        final predicted = softmax1 > softmax0 ? 1 : 0;
        isArrhythmia = predicted == 1;
        rawProb = isArrhythmia ? softmax1 : softmax0;
        confidence = rawProb * 100.0;
      } else {
        // Generic: take first element with sigmoid
        if (outShape.length == 2) {
          rawProb = (output[0][0] as num).toDouble();
        } else {
          rawProb = (output[0] as num).toDouble();
        }
        // Apply sigmoid
        rawProb = 1 / (1 + exp(-rawProb));
        isArrhythmia = rawProb > 0.5;
        confidence = (isArrhythmia ? rawProb : 1.0 - rawProb) * 100.0;
      }
    } catch (e) {
      throw Exception('Failed to parse model output: $e');
    }

    // Clamp confidence to valid range [0, 100]
    confidence = confidence.clamp(0.0, 100.0);

    final result = {
      'label': isArrhythmia ? 'ARRHYTHMIA' : 'NORMAL',
      'confidence': confidence,
      'rawOutput': rawProb,
      'isArrhythmia': isArrhythmia,
    };

    print('✅ Result: ${result['label']} (${confidence.toStringAsFixed(2)}%) raw=$rawProb');

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