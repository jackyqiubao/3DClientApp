import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/metadata_form_screen.dart';
import 'screens/query_artifacts_screen.dart';
import 'services/api_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Adjust this per platform if needed (Android emulator usually uses 10.0.2.2).
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String baseUrl =
      prefs.getString('base_url') ?? 'http://35.236.171.244:5888';

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 0, 140, 255),
        ),
        useMaterial3: true,
      ),
      home: QueryArtifactsScreen(apiService: apiService),
    );
  }
}
