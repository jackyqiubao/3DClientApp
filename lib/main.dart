import 'package:flutter/material.dart';

import 'screens/metadata_form_screen.dart';
import 'screens/query_artifacts_screen.dart';
import 'services/api_service.dart';

void main() {
  // Adjust this per platform if needed (Android emulator usually uses 10.0.2.2).
  const String baseUrl = 'http://192.168.1.162:5000';
  final ApiService apiService = ApiService(baseUrl);

  runApp(MyApp(apiService: apiService));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.apiService});

  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Artifact Capture',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: QueryArtifactsScreen(apiService: apiService),
    );
  }
}
