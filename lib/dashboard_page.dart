import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sensor_detail_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late DatabaseReference _databaseRef;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  double _temperature = 0.0;
  double _ph = 0.0;
  double _turbidity = 0.0;
  double _waterLevel = 0.0;
  int _timestamp = 0;

  Map<String, Map<String, double>> sensorLimits = {
    'temperature': {'min': 0, 'max': 50},
    'ph level': {'min': 0, 'max': 14},
    'turbidity': {'min': 0, 'max': 100},
    'water level': {'min': 0, 'max': 200},
  };

  bool _limitsLoaded = false;

  @override
  void initState() {
    super.initState();
    final app = Firebase.app('myCustomApp');
    _databaseRef = FirebaseDatabase.instanceFor(app: app).ref();

    _fetchSensorLimits().then((_) {
      setState(() {
        _limitsLoaded = true;
      });
    });

    _setupRealtimeListener();
  }

  Future<void> _fetchSensorLimits() async {
    final sensors = ['temperature', 'ph level', 'turbidity', 'water level'];
    for (var sensor in sensors) {
      final doc = await _firestore.collection('sensorSettings').doc(sensor).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          sensorLimits[sensor] = {
            'min': (data['min'] ?? 0).toDouble(),
            'max': (data['max'] ?? 100).toDouble(),
          };
        }
      }
    }
  }

  void _setupRealtimeListener() {
    _databaseRef.onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value;

      if (data != null && mounted) {
        Map<dynamic, dynamic> sensorData;
        if (data is Map) {
          sensorData = data;
        } else {
          debugPrint('Unexpected data format: ${data.runtimeType}');
          return;
        }

        setState(() {
          _temperature = (sensorData['temperature'] ?? 0.0).toDouble();
          _ph = (sensorData['ph level'] ?? 0.0).toDouble();
          _turbidity = (sensorData['turbidity'] ?? 0.0).toDouble();
          _waterLevel = (sensorData['water level'] ?? 0.0).toDouble();
          _timestamp = (sensorData['timestamp'] ?? 0).toInt();
        });
      }
    }, onError: (error) {
      debugPrint('Error reading data: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_limitsLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSensorCard('Temperature', _temperature, '°C', 'temperature', Icons.thermostat),
            _buildSensorCard('pH Level', _ph, '', 'ph level', Icons.science),
            _buildSensorCard('Turbidity', _turbidity, 'NTU', 'turbidity', Icons.water_drop),
            _buildSensorCard('Water Level', _waterLevel, 'cm', 'water level', Icons.waves),
            const SizedBox(height: 20),
            Text(
              'Last updated: ${_formatTimestamp(_timestamp)}',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorCard(String title, double value, String unit, String dataKey, IconData icon) {
    final min = sensorLimits[dataKey]?['min'] ?? 0;
    final max = sensorLimits[dataKey]?['max'] ?? 100;
    final normalizedValue = ((value - min) / (max - min)).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SensorDetailPage(
              sensorName: title,
              unit: unit,
              minValue: min,
              maxValue: max,
              databaseRef: _databaseRef,
              dataKey: dataKey,
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${value.toStringAsFixed(2)}$unit',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _getValueColor(normalizedValue),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: normalizedValue,
                  minHeight: 10,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getValueColor(normalizedValue),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$min$unit'),
                  Text('$max$unit'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getValueColor(double normalizedValue) {
    return Color.lerp(Colors.green, Colors.red, normalizedValue)!;
  }

  String _formatTimestamp(int timestamp) {
    if (timestamp == 0) return 'Never';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }
}
