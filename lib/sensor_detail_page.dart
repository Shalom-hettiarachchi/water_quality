import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

// Data model
class SensorDataPoint {
  final DateTime time;
  final double value;

  SensorDataPoint(this.time, this.value);
}

class SensorDetailPage extends StatefulWidget {
  final String sensorName;
  final String unit;
  final double minValue;
  final double maxValue;
  final DatabaseReference databaseRef;
  final String dataKey;

  const SensorDetailPage({
    super.key,
    required this.sensorName,
    required this.unit,
    required this.minValue,
    required this.maxValue,
    required this.databaseRef,
    required this.dataKey,
  });

  @override
  State<SensorDetailPage> createState() => _SensorDetailPageState();
}

class _SensorDetailPageState extends State<SensorDetailPage> {
  double? _currentValue;  // Nullable to handle the initial value
  List<SensorDataPoint> _dataPoints = [];
  late StreamSubscription<DatabaseEvent> _sensorSubscription;
  bool _isDataLoaded = false; // Flag to track data loading status

  @override
  void initState() {
    super.initState();
    _startListeningToSensor();
  }

  void _startListeningToSensor() {
    _sensorSubscription = widget.databaseRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null && data.containsKey(widget.dataKey)) {
        final dynamic rawValue = data[widget.dataKey];
        final double value = (rawValue is int) ? rawValue.toDouble() : rawValue;

        if (!mounted) return;

        setState(() {
          _currentValue = value;
          _isDataLoaded = true;  // Data is loaded
          _dataPoints.add(SensorDataPoint(DateTime.now(), value));
          if (_dataPoints.length > 100) _dataPoints.removeAt(0);
        });
      }
    });
  }

  @override
  void dispose() {
    _sensorSubscription.cancel(); // Cancel the Firebase listener
    _dataPoints.clear(); // Clean slate before widget is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.sensorName} Overview'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isDataLoaded
            ? Column(
                children: [
                  _buildCircularGauge(),
                  const SizedBox(height: 20),
                  _buildLinearGauge(),
                  const SizedBox(height: 30),
                  Expanded(child: _buildLineChart()),
                ],
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildCircularGauge() {
    return SizedBox(
      child: SfRadialGauge(
        enableLoadingAnimation: true, // Enable initial loading animation
        title: GaugeTitle(
          text: '${widget.sensorName} Reading',
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        axes: <RadialAxis>[
          RadialAxis(
            minimum: widget.minValue,
            maximum: widget.maxValue,
            pointers: <GaugePointer>[
              NeedlePointer(
                value: _currentValue ?? widget.minValue, // Default to min value
                needleColor: Colors.red,  // Always red needle
                needleLength: 0.65,
                enableAnimation: true, // Enable animation
                animationDuration: 1000, // Animation duration in milliseconds
                animationType: AnimationType.ease, // Animation type (ease, linear, etc.)
                knobStyle: const KnobStyle(
                  knobRadius: 0.1,
                  sizeUnit: GaugeSizeUnit.factor,
                  color: Colors.red,
                ),
              ),
            ],
            axisLineStyle: AxisLineStyle(
              gradient: SweepGradient(
                colors: <Color>[Colors.green, Colors.red], // Green to Red gradient
                stops: <double>[0.0, 1.0], // The gradient transition from green to red
              ),
              thickness: 15,
            ),
            annotations: <GaugeAnnotation>[
              GaugeAnnotation(
                widget: Text(
                  '${_currentValue?.toStringAsFixed(2) ?? widget.minValue.toStringAsFixed(2)} ${widget.unit}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                angle: 90,
                positionFactor: 0.8,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLinearGauge() {
    if (_currentValue == null || _currentValue!.isNaN || _currentValue! < widget.minValue || _currentValue! > widget.maxValue) {
      return const SizedBox.shrink();  // Avoid building gauge if value is unsafe or null
    }

    double safeValue = (_currentValue ?? widget.minValue).clamp(widget.minValue, widget.maxValue);

    return SfLinearGauge(
      minimum: widget.minValue,
      maximum: widget.maxValue,
      showLabels: true,
      animateAxis: true, // Animate axis changes
      animationDuration: 1000, // Animation duration in milliseconds
      markerPointers: [
        LinearWidgetPointer(
          value: safeValue,
          enableAnimation: true, // Enable animation for the widget pointer
          animationDuration: 1000, // Animation duration in milliseconds
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${safeValue.toStringAsFixed(1)} ${widget.unit}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
      barPointers: [
        LinearBarPointer(
          value: safeValue,
          color: Colors.blueAccent,
          enableAnimation: true, // Enable animation for the bar pointer
          animationDuration: 1000, // Animation duration in milliseconds
        ),
      ],
    );
  }

  Widget _buildLineChart() {
    return SfCartesianChart(
      title: ChartTitle(text: 'Live ${widget.sensorName} Data'),
      primaryXAxis: DateTimeAxis(
        intervalType: DateTimeIntervalType.seconds,
      ),
      primaryYAxis: NumericAxis(
        minimum: widget.minValue,
        maximum: widget.maxValue,
        title: AxisTitle(text: widget.unit),
      ),
      series: <LineSeries<SensorDataPoint, DateTime>>[
        LineSeries<SensorDataPoint, DateTime>(
          dataSource: _dataPoints,
          xValueMapper: (SensorDataPoint point, _) => point.time,
          yValueMapper: (SensorDataPoint point, _) => point.value,
          color: Colors.redAccent,
          width: 2,
          markerSettings: const MarkerSettings(isVisible: true),
          animationDuration: 500, // Add animation to the chart as well
        )
      ],
    );
  }
}