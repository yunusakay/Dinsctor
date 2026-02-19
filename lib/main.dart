import 'package:flutter/foundation.dart'; // REQUIRED for kIsWeb
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Make sure you ran 'flutterfire configure'

// Screens
import 'screens/web_landing_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SsCer Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      // THE MAGIC SWITCH
      // If running on Chrome -> Show Projector Screen
      // If running on Phone  -> Show Login Screen
      home: kIsWeb ? WebLandingScreen() : LoginScreen(),
    );
  }
}