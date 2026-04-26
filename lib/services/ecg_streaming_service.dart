import 'dart:async';
import 'dart:math';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart';
import 'csv_service.dart';

/// Callback for ECG data updates
typedef ECGDataCallback = void Function(List<double> buffer, double latestValue);
typedef InferenceReadyCallback = void Function(List<double> buffer);

/// Service for streaming ECG data from CSV file
/// Supports both sample data and custom user-uploaded CSV files
class ECGStreamingService {
  static final ECGStreamingService _instance = ECGStreamingService._internal();

  ECGStreamingService._internal();

  factory ECGStreamingService() {
    return _instance;
  }

  /// CSV service for file operations
  final CSVService _csvService = CSVService();

  /// All ECG data loaded from CSV
  List<double> _allECGData = [];

  /// Current buffer (rolling window of 187 values)
  List<double> _buffer = [];

  /// Buffer size for inference
  static const int bufferSize = 187;

  /// Stream interval (milliseconds) - adjust for real-time feel
  static const int streamInterval = 50; // 20 samples per second

  /// Timer for streaming
  Timer? _streamTimer;

  /// Current index in data stream
  int _currentIndex = 0;

  /// Streaming active flag
  bool _isStreaming = false;

  /// Data source info
  String _dataSource = 'sample'; // 'sample' or 'custom'
  String _fileName = '';

  /// Data callbacks
  ECGDataCallback? _onDataUpdate;
  InferenceReadyCallback? _onInferenceReady;

  /// Status getters
  bool get isStreaming => _isStreaming;
  bool get isBufferFull => _buffer.length == bufferSize;
  int get currentDataPoints => _allECGData.length;
  int get bufferFilledPercentage => (_buffer.length * 100 ~/ bufferSize);
  List<double> get currentBuffer => List.from(_buffer);
  String get dataSource => _dataSource;
  String get fileName => _fileName;
  bool get hasCustomData => _dataSource == 'custom';

  /// Load custom ECG data from user-selected CSV file
  Future<bool> loadCustomCSV() async {
    try {
      print('📁 Loading custom CSV data...');

      List<double> customData = await _csvService.loadCSVFromFile();

      if (customData.isEmpty) {
        print('⚠️  No data loaded from custom CSV');
        return false;
      }

      // Validate data
      var validation = _csvService.validateECGData(customData);
      if (!validation['isValid']) {
        throw Exception(validation['error']);
      }

      // Stop current streaming if active
      if (_isStreaming) {
        stopStreaming();
      }

      // Update data
      _allECGData = customData;
      _dataSource = 'custom';
      _fileName = 'Custom CSV'; // Could be enhanced to get actual filename

      // Normalize data
      _normalizeData();

      // Reset streaming state
      _buffer.clear();
      _currentIndex = 0;

      // Prefill buffer with first window so UI/inference can run immediately
      final prefillLength = _allECGData.length >= bufferSize ? bufferSize : _allECGData.length;
      if (prefillLength > 0) {
        _buffer = _allECGData.sublist(0, prefillLength).toList();
        // Notify UI about data and latest value
        _onDataUpdate?.call(List.from(_buffer), _buffer.isNotEmpty ? _buffer.last : 0.0);

        // If buffer is full, immediately notify inference ready
        if (_buffer.length == bufferSize && _onInferenceReady != null) {
          print('🔔 Buffer prefilled with $prefillLength points; triggering inference callback');
          _onInferenceReady!.call(List.from(_buffer));
        }
      }

      print('✅ Custom CSV loaded: ${customData.length} points');
      print('📊 Data range: ${validation['minValue']?.toStringAsFixed(4)} - ${validation['maxValue']?.toStringAsFixed(4)}');

      return true;

    } catch (e) {
      print('❌ Error loading custom CSV: $e');
      return false;
    }
  }

  /// Reset to sample data
  Future<void> resetToSampleData() async {
    try {
      print('🔄 Resetting to sample data...');

      // Stop current streaming
      if (_isStreaming) {
        stopStreaming();
      }

      // Reload sample data
      await initialize();

      _dataSource = 'sample';
      _fileName = '';

      print('✅ Reset to sample data');
    } catch (e) {
      print('❌ Error resetting to sample data: $e');
    }
  }

  /// Initialize service (load CSV data)
  Future<void> initialize() async {
    try {
      print('📦 Loading ECG data from assets...');
      final csvString = await rootBundle.loadString('assets/sample_ecg.csv');

      // Parse CSV
      List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);

      // Extract numeric values (skip header if exists)
      for (var row in rows) {
        if (row.isNotEmpty && row[0] is! String) {
          _allECGData.add(double.parse(row[0].toString()));
        } else if (row[0] is String && row[0] != 'ECG' && row[0] != 'value') {
          try {
            _allECGData.add(double.parse(row[0]));
          } catch (e) {
            // Skip non-numeric rows
          }
        }
      }

      // If CSV has no data, use fallback
      if (_allECGData.isEmpty) {
        print('⚠️  No data in CSV, using synthetic data');
        _generateSyntheticData();
      }

      // Normalize data to [0, 1]
      _normalizeData();

      print('✅ Loaded ${_allECGData.length} ECG data points');
      print('📊 Data range: ${_allECGData.reduce((a, b) => a < b ? a : b).toStringAsFixed(4)} - ${_allECGData.reduce((a, b) => a > b ? a : b).toStringAsFixed(4)}');
    } catch (e) {
      print('❌ Error loading ECG data: $e');
      _generateSyntheticData();
    }
  }

  /// Generate synthetic ECG data if CSV is empty
  void _generateSyntheticData() {
    const int dataPoints = 5000;
    for (int i = 0; i < dataPoints; i++) {
      double t = i / 100.0;
      // Simulate ECG-like signal
      double value = 0.5 +
          0.3 * sin(t % 1) +
          0.1 * sin((2 * t) % 1) +
          0.05 * sin((0.5 * t) % 1);
      value = value.clamp(0.0, 1.0);
      _allECGData.add(value);
    }
    print('🔧 Generated synthetic ECG data: ${_allECGData.length} points');
  }

  /// Normalize data to [0, 1] range
  void _normalizeData() {
    if (_allECGData.isEmpty) return;

    double min = _allECGData.reduce((a, b) => a < b ? a : b);
    double max = _allECGData.reduce((a, b) => a > b ? a : b);
    double range = max - min;

    if (range == 0) range = 1.0;

    _allECGData = _allECGData
        .map((value) => (value - min) / range)
        .toList();
  }

  /// Register callback for data updates
  void onDataUpdate(ECGDataCallback callback) {
    _onDataUpdate = callback;
  }

  /// Register callback for inference ready
  void onInferenceReady(InferenceReadyCallback callback) {
    _onInferenceReady = callback;
  }

  /// Start streaming ECG data
  void startStreaming() {
    if (_isStreaming) {
      print('⚠️  Streaming already active');
      return;
    }

    if (_allECGData.isEmpty) {
      print('❌ No ECG data loaded');
      return;
    }

    print('▶️  Starting ECG stream...');
    _isStreaming = true;
    _currentIndex = 0;
    _buffer.clear();

    _streamTimer = Timer.periodic(Duration(milliseconds: streamInterval), (timer) {
      _processStreamTick();
    });
  }

  /// Stop streaming
  void stopStreaming() {
    if (!_isStreaming) return;

    _streamTimer?.cancel();
    _streamTimer = null;
    _isStreaming = false;
    print('⏹️  ECG stream stopped');
  }

  /// Process one tick of data streaming
  void _processStreamTick() {
    if (_currentIndex >= _allECGData.length) {
      // Loop back to start
      _currentIndex = 0;
      print('🔄 ECG data looped');
    }

    // Get next value
    double nextValue = _allECGData[_currentIndex];
    _currentIndex++;

    // Add to buffer
    _buffer.add(nextValue);

    // Keep buffer at fixed size
    if (_buffer.length > bufferSize) {
      _buffer.removeAt(0);
    }

    // Notify data update
    _onDataUpdate?.call(List.from(_buffer), nextValue);

    // If buffer is full, notify inference ready
    if (_buffer.length == bufferSize && _onInferenceReady != null) {
      _onInferenceReady!.call(List.from(_buffer));
    }
  }

  /// Reset streaming
  void reset() {
    stopStreaming();
    _buffer.clear();
    _currentIndex = 0;
    print('🔄 ECG stream reset');
  }

  /// sample of ECG data
  List<double> getSampleECGData(int length) {
    if (_allECGData.isEmpty) {
      return [];
    }
    length = length > _allECGData.length ? _allECGData.length : length;
    return _allECGData.sublist(0, length);
  }

  List<double> getAllECGData() {
    return List.from(_allECGData);
  }

  void dispose() {
    stopStreaming();
    print('🔌 ECG Streaming Service disposed');
  }
}
