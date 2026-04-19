import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';

/// Service for handling CSV file operations
/// Supports loading custom ECG data from user-selected CSV files
class CSVService {
  static final CSVService _instance = CSVService._internal();

  CSVService._internal();

  factory CSVService() {
    return _instance;
  }

  /// Load ECG data from a user-selected CSV file
  Future<List<double>> loadCSVFromFile() async {
    try {
      print('📁 Opening file picker...');

      // Pick a CSV file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        print('⚠️  No file selected');
        return [];
      }

      final file = result.files.first;
      print('📄 Selected file: ${file.name}');

      String csvContent;

      // Read file content
      if (file.path != null) {
        // File from file system
        csvContent = await File(file.path!).readAsString();
      } else if (file.bytes != null) {
        // File from web/mobile (bytes)
        csvContent = String.fromCharCodes(file.bytes!);
      } else {
        throw Exception('Unable to read file content');
      }

      // Parse CSV and extract numeric values
      List<double> ecgData = _parseCSVContent(csvContent);

      if (ecgData.isEmpty) {
        throw Exception('No valid numeric data found in CSV');
      }

      print('✅ Successfully loaded ${ecgData.length} ECG data points from ${file.name}');
      return ecgData;

    } catch (e) {
      print('❌ Error loading CSV file: $e');
      rethrow;
    }
  }

  /// Parse CSV content and extract numeric values
  List<double> _parseCSVContent(String csvContent) {
    List<double> ecgData = [];

    try {
      // Parse CSV
      List<List<dynamic>> rows = const CsvToListConverter().convert(csvContent);

      print('📊 Parsed ${rows.length} rows from CSV');

      // Extract numeric values from each row
      for (int i = 0; i < rows.length; i++) {
        var row = rows[i];

        if (row.isEmpty) continue;

        // Try to extract numeric value from the first column
        double? value = _extractNumericValue(row[0]);

        if (value != null) {
          ecgData.add(value);
        } else {
          print('⚠️  Skipping non-numeric row ${i + 1}: ${row[0]}');
        }
      }

      // Validate minimum data requirement
      if (ecgData.length < 187) {
        throw Exception('CSV must contain at least 187 data points for inference. Found: ${ecgData.length}');
      }

    } catch (e) {
      print('❌ Error parsing CSV content: $e');
      rethrow;
    }

    return ecgData;
  }

  /// Extract numeric value from various formats
  double? _extractNumericValue(dynamic value) {
    if (value == null) return null;

    try {
      // Convert to string and clean
      String strValue = value.toString().trim();

      // Skip headers or non-numeric strings
      if (strValue.isEmpty ||
          strValue.toLowerCase() == 'ecg' ||
          strValue.toLowerCase() == 'value' ||
          strValue.toLowerCase() == 'data') {
        return null;
      }

      // Parse as double
      return double.parse(strValue);
    } catch (e) {
      // Try to handle comma-separated decimals (European format)
      try {
        String strValue = value.toString().trim();
        strValue = strValue.replaceAll(',', '.');
        return double.parse(strValue);
      } catch (e2) {
        return null;
      }
    }
  }

  /// Validate CSV data quality
  Map<String, dynamic> validateECGData(List<double> data) {
    if (data.isEmpty) {
      return {
        'isValid': false,
        'error': 'No data found',
        'dataPoints': 0,
      };
    }

    // Check minimum requirements
    if (data.length < 187) {
      return {
        'isValid': false,
        'error': 'Insufficient data: need at least 187 points',
        'dataPoints': data.length,
      };
    }

    // Check data range (should be reasonable ECG values)
    double min = data.reduce((a, b) => a < b ? a : b);
    double max = data.reduce((a, b) => a > b ? a : b);

    // ECG data typically ranges from -2 to +2 mV, but normalized data is 0-1
    bool reasonableRange = min >= -5 && max <= 5;

    if (!reasonableRange) {
      print('⚠️  Data range seems unusual: $min to $max');
    }

    return {
      'isValid': true,
      'dataPoints': data.length,
      'minValue': min,
      'maxValue': max,
      'range': max - min,
    };
  }
}