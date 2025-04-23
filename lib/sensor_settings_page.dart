import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SensorSettingsPage extends StatefulWidget {
  const SensorSettingsPage({super.key});

  @override
  State<SensorSettingsPage> createState() => _SensorSettingsPageState();
}

class _SensorSettingsPageState extends State<SensorSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;

  final List<String> _sensors = ['temperature', 'ph level', 'turbidity', 'water level'];
  String? _selectedSensor;

  late TextEditingController _minController;
  late TextEditingController _maxController;
  late TextEditingController _minAlarmController;
  late TextEditingController _maxAlarmController;

  @override
  void initState() {
    super.initState();
    _minController = TextEditingController();
    _maxController = TextEditingController();
    _minAlarmController = TextEditingController();
    _maxAlarmController = TextEditingController();
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    _minAlarmController.dispose();
    _maxAlarmController.dispose();
    super.dispose();
  }

  Future<void> _loadSensorSettings(String sensor) async {
    final doc = await _firestore.collection('sensorSettings').doc(sensor).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _minController.text = (data['min'] ?? '').toString();
        _maxController.text = (data['max'] ?? '').toString();
        _minAlarmController.text = (data['minAlarm'] ?? '').toString();
        _maxAlarmController.text = (data['maxAlarm'] ?? '').toString();
      });
    } else {
      setState(() {
        _minController.clear();
        _maxController.clear();
        _minAlarmController.clear();
        _maxAlarmController.clear();
      });
    }
  }

  Future<void> _saveSensorSettings() async {
    if (_formKey.currentState!.validate() && _selectedSensor != null) {
      await _firestore.collection('sensorSettings').doc(_selectedSensor).set({
        'min': double.tryParse(_minController.text),
        'max': double.tryParse(_maxController.text),
        'minAlarm': double.tryParse(_minAlarmController.text),
        'maxAlarm': double.tryParse(_maxAlarmController.text),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sensor settings saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sensor Settings")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedSensor,
                decoration: const InputDecoration(labelText: 'Select Sensor'),
                items: _sensors.map((sensor) {
                  return DropdownMenuItem(value: sensor, child: Text(sensor));
                }).toList(),
                onChanged: (sensor) {
                  setState(() {
                    _selectedSensor = sensor;
                  });
                  _loadSensorSettings(sensor!);
                },
                validator: (value) => value == null ? 'Please select a sensor' : null,
              ),
              const SizedBox(height: 20),
              _buildNumberField("Min Value", _minController),
              _buildNumberField("Max Value", _maxController),
              _buildNumberField("Min Alarm Value", _minAlarmController),
              _buildNumberField("Max Alarm Value", _maxAlarmController),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveSensorSettings,
                child: const Text("Save Settings"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Enter $label';
        if (double.tryParse(value) == null) return 'Enter a valid number';
        return null;
      },
    );
  }
}
