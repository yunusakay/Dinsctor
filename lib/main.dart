import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/web_landing_screen.dart';
import 'screens/student_screen.dart';
import 'screens/teacher_remote_screen.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const StudentsCheckerApp());
}

class StudentsCheckerApp extends StatelessWidget {
  const StudentsCheckerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dinsctor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      // NO 'const' here because WebLandingScreen and LoginScreen are dynamic
      // Temporarily change main.dart for debugging
      home: kIsWeb ? TeacherRemoteScreen() : LoginScreen(),
      routes: {
        '/login': (context) => LoginScreen(),
        '/teacher': (context) => TeacherRemoteScreen(),
        '/student': (context) => StudentScreen(),
      },
    );
  }
}