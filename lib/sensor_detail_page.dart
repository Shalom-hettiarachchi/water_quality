import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart' as gauges;
import 'package:syncfusion_flutter_charts/charts.dart' as charts;

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
  double? _currentValue;
  List<SensorDataPoint> _dataPoints = [];
  late StreamSubscription<DatabaseEvent> _sensorSubscription;
  bool _isDataLoaded = false;

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
          _isDataLoaded = true;
          _dataPoints.add(SensorDataPoint(DateTime.now(), value));
          if (_dataPoints.length > 100) _dataPoints.removeAt(0);
        });
      }
    });
  }

  @override
  void dispose() {
    _sensorSubscription.cancel();
    _dataPoints.clear();
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
      child: gauges.SfRadialGauge(
        enableLoadingAnimation: true,
        title: gauges.GaugeTitle(
          text: '${widget.sensorName} Reading',
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        axes: <gauges.RadialAxis>[
          gauges.RadialAxis(
            minimum: widget.minValue,
            maximum: widget.maxValue,
            pointers: <gauges.GaugePointer>[
              gauges.NeedlePointer(
                value: _currentValue ?? widget.minValue,
                needleColor: Colors.red,
                needleLength: 0.65,
                enableAnimation: true,
                animationDuration: 1000,
                animationType: gauges.AnimationType.ease,
                knobStyle: const gauges.KnobStyle(
                  knobRadius: 0.1,
                  sizeUnit: gauges.GaugeSizeUnit.factor,
                  color: Colors.red,
                ),
              ),
            ],
            axisLineStyle: gauges.AxisLineStyle(
              gradient: const SweepGradient(
                colors: <Color>[Colors.green, Colors.red],
                stops: <double>[0.0, 1.0],
              ),
              thickness: 15,
            ),
            annotations: <gauges.GaugeAnnotation>[
              gauges.GaugeAnnotation(
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
      return const SizedBox.shrink();
    }

    double safeValue = (_currentValue ?? widget.minValue).clamp(widget.minValue, widget.maxValue);

    return gauges.SfLinearGauge(
      minimum: widget.minValue,
      maximum: widget.maxValue,
      showLabels: true,
      animateAxis: true,
      animationDuration: 1000,
      markerPointers: [
        gauges.LinearWidgetPointer(
          value: safeValue,
          enableAnimation: true,
          animationDuration: 1000,
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
        gauges.LinearBarPointer(
          value: safeValue,
          color: Colors.blueAccent,
          enableAnimation: true,
          animationDuration: 1000,
        ),
      ],
    );
  }

  Widget _buildLineChart() {
    return charts.SfCartesianChart(
      title: charts.ChartTitle(text: 'Live ${widget.sensorName} Data'),
      primaryXAxis: charts.DateTimeAxis(
        intervalType: charts.DateTimeIntervalType.seconds,
      ),
      primaryYAxis: charts.NumericAxis(
        minimum: widget.minValue,
        maximum: widget.maxValue,
        title: charts.AxisTitle(text: widget.unit),
      ),
      series: <charts.LineSeries<SensorDataPoint, DateTime>>[
        charts.LineSeries<SensorDataPoint, DateTime>(
          dataSource: _dataPoints,
          xValueMapper: (SensorDataPoint point, _) => point.time,
          yValueMapper: (SensorDataPoint point, _) => point.value,
          color: Colors.redAccent,
          width: 2,
          markerSettings: const charts.MarkerSettings(isVisible: true),
          animationDuration: 500,
        )
      ],
    );
  }
}
