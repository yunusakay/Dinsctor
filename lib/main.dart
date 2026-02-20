import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added: This fixes your errors
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
      // Logic: Web shows Projector. Mobile checks if already logged in.
      home: kIsWeb
          ? const WebLandingScreen()
          : StreamBuilder<User?>( // Fixed: Now 'User' is recognized
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            // If user exists, we need to know their role to route them
            return const LoginScreen(); // LoginScreen handles role-redirection in its initState
          }
          return const LoginScreen();
        },
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/teacher': (context) => const TeacherRemoteScreen(),
        '/student': (context) => const StudentScreen(),
      },
    );
  }
}