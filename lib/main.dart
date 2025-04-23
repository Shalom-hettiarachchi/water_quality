import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:water_quality/firebase_options.dart';
import 'package:water_quality/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    name: 'myCustomApp',
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const WaterQualityApp());
}


class WaterQualityApp extends StatelessWidget {
  const WaterQualityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Water Quality Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MainScreen(),
    );
  }
}