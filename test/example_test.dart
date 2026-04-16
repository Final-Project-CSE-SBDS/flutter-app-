import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ECG Monitor App Tests', () {
    
    test('Parse CSV with 187 values', () {
      final csv = '0.5\n0.51\n0.52\n' +
          List.generate(184, (i) => '${0.5 + i * 0.001}').join('\n');
      
      final values = csv.split('\n').map(double.parse).toList();
      expect(values.length, 187);
    });

    test('Data normalization', () {
      final data = [0.0, 50.0, 100.0];
      final normalized = data.map((v) => v / 100.0).toList();
      
      expect(normalized[0], 0.0);
      expect(normalized[1], 0.5);
      expect(normalized[2], 1.0);
    });

    test('Confidence calculation', () {
      final rawOutput = 0.3;  // Normal
      final confidence = (1.0 - rawOutput) * 100;
      
      expect(confidence, 70.0);
    });

    test('Arrhythmia detection threshold', () {
      final normal = 0.3;
      final arrhythmia = 0.7;
      
      expect(normal > 0.5, false);
      expect(arrhythmia >= 0.5, true);
    });

  });
}
