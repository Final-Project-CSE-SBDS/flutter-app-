import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ECGGraphWidget extends StatefulWidget {
  
  final List<double> ecgData;

  final bool showGrid;

  
  final Color lineColor;

  final Color backgroundColor;

  final double spotRadius;

  const ECGGraphWidget({
    Key? key,
    required this.ecgData,
    this.showGrid = true,
    this.lineColor = const Color(0xFF1E88E5),
    this.backgroundColor = Colors.white,
    this.spotRadius = 0.0,
  }) : super(key: key);

  @override
  State<ECGGraphWidget> createState() => _ECGGraphWidgetState();
}

class _ECGGraphWidgetState extends State<ECGGraphWidget> {
  /// Convert ECG data to FlChart spots
  List<FlSpot> _getChartData() {
    List<FlSpot> spots = [];
    for (int i = 0; i < widget.ecgData.length; i++) {
      spots.add(FlSpot(i.toDouble(), widget.ecgData[i]));
    }
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final spots = _getChartData();

    if (spots.isEmpty) {
      return Container(
        color: widget.backgroundColor,
        child: const Center(
          child: Text('Waiting for ECG data...'),
        ),
      );
    }

    return Container(
      color: widget.backgroundColor,
      child: LineChart(
        LineChartData(
         
          gridData: FlGridData(
            show: widget.showGrid,
            drawVerticalLine: true,
            drawHorizontalLine: true,
            horizontalInterval: 0.1,
            verticalInterval: 20,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.withOpacity(0.3),
                strokeWidth: 0.5,
              );
            },
            getDrawingVerticalLine: (value) {
              return FlLine(
                color: Colors.grey.withOpacity(0.2),
                strokeWidth: 0.5,
              );
            },
          ),

          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (spots.length / 5).ceil().toDouble(),
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 0.2,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
          ),

          // Border
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: Colors.grey.withOpacity(0.5),
              width: 1,
            ),
          ),

          minX: 0,
          maxX: (spots.length - 1).toDouble(),
          minY: 0,
          maxY: 1.0,

      
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: widget.lineColor,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: false,
              ),
              belowBarData: BarAreaData(
                show: true,
                color: widget.lineColor.withOpacity(0.15),
              ),
            ),
          ],

          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              tooltipRoundedRadius: 8,
              getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                return touchedBarSpots.map(
                  (barSpot) {
                    return LineTooltipItem(
                      'Value: ${barSpot.y.toStringAsFixed(3)}\nIndex: ${barSpot.x.toInt()}',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}

class MinimalECGGraph extends StatelessWidget {
  final List<double> ecgData;
  final Color lineColor;
  final bool showLabels;

  const MinimalECGGraph({
    Key? key,
    required this.ecgData,
    this.lineColor = Colors.green,
    this.showLabels = false,
  }) : super(key: key);

  List<FlSpot> _getChartData() {
    List<FlSpot> spots = [];
    for (int i = 0; i < ecgData.length; i++) {
      spots.add(FlSpot(i.toDouble(), ecgData[i]));
    }
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final spots = _getChartData();

    if (spots.isEmpty) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            'Waiting...',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (spots.length - 1).toDouble(),
          minY: 0,
          maxY: 1.0,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: lineColor,
              barWidth: 1.5,
              dotData: FlDotData(show: false),
            ),
          ],
          lineTouchData: LineTouchData(enabled: false),
        ),
      ),
    );
  }
}
