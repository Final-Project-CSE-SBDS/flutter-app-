import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';
import '../widgets/ecg_graph.dart';

/// Watch Screen - Receives ECG predictions via Bluetooth
/// Displays real-time BLE data from connected ECG device
class WatchScreen extends StatefulWidget {
  const WatchScreen({Key? key}) : super(key: key);

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  /// Current prediction status
  String _status = 'Waiting for data...';

  /// Prediction history
  List<Map<String, dynamic>> _history = [];

  /// Is connected to BLE device
  bool _isConnected = false;

  /// Sample ECG data for display
  List<double> _displayECGData = [];
  
  /// Bluetooth service instance
  late BluetoothService _bluetoothService;

  @override
  void initState() {
    super.initState();
    _setupBLEReception();
  }

  /// Setup real BLE data reception from BluetoothService
  void _setupBLEReception() {
    _bluetoothService = BluetoothService();
    
    // Listen to connection state changes
    print('👀 [WatchScreen] Subscribing to BLE connection state...');
    _bluetoothService.onConnectionState((state) {
      print('📡 [WatchScreen] Connection state changed: $state');
      setState(() {
        _isConnected = state.toString().contains('connected');
      });
      if (!_isConnected) {
        _status = 'Waiting for data...';
      }
    });
    
    // Listen to received data from BLE device
    print('👂 [WatchScreen] Subscribing to BLE data stream...');
    _bluetoothService.onDataReceived((data) {
      print('📥 [WatchScreen] Received BLE data: "$data"');
      _parseAndUpdateStatus(data);
    });
    
    // Initial connection state
    setState(() {
      _isConnected = _bluetoothService.isConnected;
    });
    print(' [WatchScreen] BLE reception setup complete');
  }

  /// Parse received BLE data and update UI
  /// Format: "NORMAL" or "ARRHYTHMIA" (optionally with confidence)
  /// Examples: "NORMAL:99.5%", "ARRHYTHMIA:87.3%"
  void _parseAndUpdateStatus(String data) {
    try {
      print('🔍 [WatchScreen] Parsing BLE data: "$data"');
      
      // Trim whitespace
      String trimmedData = data.trim();
      
      String label = 'NORMAL';
      double confidence = 0.0;
      
      if (trimmedData.contains(':')) {
        // Format: "LABEL:CONFIDENCE"
        List<String> parts = trimmedData.split(':');
        label = parts[0].trim().toUpperCase();
        
        String confStr = parts[1].trim().replaceAll('%', '');
        try {
          confidence = double.parse(confStr);
        } catch (e) {
          print('⚠️ [WatchScreen] Could not parse confidence: ${parts[1]}');
          confidence = 0.0;
        }
      } else {
        // Format: "LABEL" only
        label = trimmedData.toUpperCase();
        confidence = 100.0; // Default to 100% if no confidence given
      }
      
      // Validate label
      if (label != 'NORMAL' && label != 'ARRHYTHMIA') {
        print('⚠️ [WatchScreen] Unknown label: "$label"');
        return;
      }
      
      print('✅ [WatchScreen] Parsed - Label: $label, Confidence: $confidence%');
      _updateStatus(label, confidence);
    } catch (e) {
      print('❌ [WatchScreen] Error parsing data: $e');
    }
  }

  /// Update status with new prediction
  void _updateStatus(String label, double confidence) {
    print(' [WatchScreen] Updating UI - Label: $label, Confidence: ${confidence.toStringAsFixed(1)}%');
    
    setState(() {
      _status = label;
      _history.insert(
        0,
        {
          'label': label,
          'confidence': confidence,
          'timestamp': DateTime.now(),
        },
      );

      // Keep only last 10 readings
      if (_history.length > 10) {
        _history.removeAt(_history.length - 1);
      }

      // Generate sample ECG display data based on prediction
      _displayECGData = List.generate(100, (i) {
        double t = i / 20.0;
        return 0.5 +
            0.2 * sin(t % 1) +
            0.1 * sin((2 * t) % 1) * (label == 'ARRHYTHMIA' ? 2 : 1);
      });
    });
  }

  @override
  void dispose() {
    print('🗑️ [WatchScreen] Disposing...');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('ECG Watch'),
        backgroundColor: Colors.grey[900],
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Connection Status
                _buildConnectionStatus(),
                const SizedBox(height: 20),

                // Main Status Display
                _buildStatusDisplay(),
                const SizedBox(height: 20),

                // ECG Graph
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[700]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: MinimalECGGraph(
                    ecgData: _displayECGData,
                    lineColor: _status == 'ARRHYTHMIA'
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
                const SizedBox(height: 20),

                // History
                _buildHistory(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build connection status widget
  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _isConnected
            ? Colors.green.withOpacity(0.2)
            : Colors.red.withOpacity(0.2),
        border: Border.all(
          color: _isConnected ? Colors.green : Colors.red,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 6,
            backgroundColor: _isConnected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(
            _isConnected ? 'Connected' : 'Disconnected',
            style: TextStyle(
              color: _isConnected ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Build main status display
  Widget _buildStatusDisplay() {
    bool isArrhythmia = _status == 'ARRHYTHMIA';
    Color statusColor = isArrhythmia ? Colors.red : Colors.green;
    String emoji = isArrhythmia ? '⚠️' : '💚';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(color: statusColor, width: 3),
        borderRadius: BorderRadius.circular(12),
        color: statusColor.withOpacity(0.1),
      ),
      child: Column(
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 12),
          Text(
            _status,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 8),
          if (_history.isNotEmpty)
            Text(
              'Confidence: ${_history[0]['confidence'].toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[400],
              ),
            ),
        ],
      ),
    );
  }

  /// Build history widget
  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Readings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_history.isEmpty)
          Center(
            child: Text(
              'No readings yet',
              style: TextStyle(color: Colors.grey[600]),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _history.length,
            itemBuilder: (context, index) {
              final reading = _history[index];
              bool isArrhythmia = reading['label'] == 'ARRHYTHMIA';
              Color color = isArrhythmia ? Colors.red : Colors.green;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  border: Border.all(color: Colors.grey[800]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reading['label'],
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${reading['confidence'].toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _formatTime(reading['timestamp']),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  /// Format time
  String _formatTime(DateTime time) {
    Duration diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${diff.inHours}h ago';
    }
  }
}
