import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/home_screen.dart';
import 'models/expense_model.dart';
import 'storage/hive_boxes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Hive
    await Hive.initFlutter();

    // Register adapters
    Hive.registerAdapter(ExpenseModelAdapter());

    // Open the box
    await HiveBoxes.openBoxes();

    runApp(const MyApp());
  } catch (e) {
    if (kDebugMode) {
      print('Error initializing app: $e');
    }
    // Run with limited functionality if database fails
    runApp(const MyApp(databaseError: true));
  }
}

class MyApp extends StatelessWidget {
  final bool databaseError;

  const MyApp({super.key, this.databaseError = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: databaseError ? const ErrorScreen() : const HomeScreen(),
    );
  }
}

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Expense Tracker'),
        backgroundColor: Colors.red[400],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 24),
              const Text(
                'பிழை ஏற்பட்டது / Error Occurred',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'செயலியை மீண்டும் துவக்கவும் / Please restart the app',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  main();
                },
                child: const Text('மீண்டும் முயற்சி செய்க / Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}