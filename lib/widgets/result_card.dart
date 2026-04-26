import 'package:flutter/material.dart';

class ResultCard extends StatelessWidget {
  /// Prediction label (NORMAL or ARRHYTHMIA)
  final String label;

  /// Raw model output probability
  final double rawOutput;

  /// Confidence percentage
  final double confidence;

  /// Whether prediction is arrhythmia
  final bool isArrhythmia;

  /// Optional callback when user acknowledges result
  final VoidCallback? onAcknowledge;

  const ResultCard({
    Key? key,
    required this.label,
    required this.rawOutput,
    required this.confidence,
    required this.isArrhythmia,
    this.onAcknowledge,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine colors based on prediction
    final backgroundColor = isArrhythmia
        ? const Color(0xFFFFEBEE) // Light red for arrhythmia
        : const Color(0xFFE8F5E9); // Light green for normal

    final borderColor =
        isArrhythmia ? const Color(0xFFC62828) : const Color(0xFF2E7D32);

    final textColor =
        isArrhythmia ? const Color(0xFFC62828) : const Color(0xFF1B5E20);

    final icon =
        isArrhythmia ? Icons.warning_rounded : Icons.favorite_rounded;

    final iconColor =
        isArrhythmia ? const Color(0xFFC62828) : const Color(0xFF2E7D32);

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor, width: 2),
      ),
      color: backgroundColor,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// Icon indicator
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withOpacity(0.2),
              ),
              child: Icon(
                icon,
                size: 48,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 16),

            /// Prediction label
            Text(
              label,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            /// Health status message
            Text(
              isArrhythmia
                  ? 'Abnormal heartbeat detected'
                  : 'Heart rhythm is normal',
              style: TextStyle(
                fontSize: 16,
                color: textColor.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            /// Confidence meter
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Confidence',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    Text(
                      '${confidence.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: confidence / 100,
                    minHeight: 12,
                    backgroundColor: borderColor.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(borderColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            /// Raw probability value
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Model Output: ${rawOutput.toStringAsFixed(4)}',
                style: TextStyle(
                  fontSize: 12,
                  color: textColor.withOpacity(0.6),
                  fontFamily: 'Courier',
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),

            /// Acknowledge button
            if (onAcknowledge != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onAcknowledge,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: borderColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Acknowledge',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
