import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  String _role = 'student';

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  // 1. Load saved email from local storage
  void _loadSavedEmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _emailController.text = prefs.getString('saved_email') ?? "";
      _rememberMe = _emailController.text.isNotEmpty;
    });
  }

  // 2. The missing Navigation Function
  void _navigateBasedOnRole(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

    if (!doc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User role not found in database.")));
      return;
    }

    final userRole = doc.get('role');
    if (mounted) {
      Navigator.pushReplacementNamed(context, userRole == 'teacher' ? '/teacher' : '/student');
    }
  }

  // 3. The missing Reset Password Function
  void _resetPassword() async {
    final TextEditingController _resetEmailController = TextEditingController();
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24, right: 24, top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Secure Reset", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: _resetEmailController,
              decoration: const InputDecoration(labelText: "Account Email", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                String email = _resetEmailController.text.trim();
                if (email.isEmpty) return;

                // --- SECURITY TIME RESTRICTION (COOLDOWN) ---
                int lastRequest = prefs.getInt('last_reset_request') ?? 0;
                int currentTime = DateTime.now().millisecondsSinceEpoch;

                // 60,000 milliseconds = 1 minute cooldown
                if (currentTime - lastRequest < 60000) {
                  int secondsLeft = (60000 - (currentTime - lastRequest)) ~/ 1000;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Please wait $secondsLeft seconds before requesting again.")),
                  );
                  return;
                }

                try {
                  await _auth.sendPasswordResetEmail(email: email);

                  // Update the last request time
                  await prefs.setInt('last_reset_request', currentTime);

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Reset link sent!"), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              child: const Text("SEND RESET LINK"),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('saved_email', _emailController.text.trim());
      } else {
        await prefs.remove('saved_email');
      }

      if (_isLogin) {
        final user = await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        _navigateBasedOnRole(user.user!.uid);
      } else {
        final user = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        await FirebaseFirestore.instance.collection('users').doc(user.user!.uid).set({
          'role': _role,
          'email': _emailController.text.trim(),
        });
        _navigateBasedOnRole(user.user!.uid);
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Error")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Text("Dinsctor", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF3182CE))),
              const SizedBox(height: 10),
              Text(_isLogin ? "Welcome Back" : "Create Account", style: const TextStyle(fontSize: 18, color: Colors.grey)),
              const SizedBox(height: 40),
              TextField(controller: _emailController, decoration: const InputDecoration(hintText: "Email", border: OutlineInputBorder())),
              const SizedBox(height: 15),
              TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(hintText: "Password", border: OutlineInputBorder())),

              Row(
                children: [
                  Checkbox(value: _rememberMe, onChanged: (v) => setState(() => _rememberMe = v!)),
                  const Text("Remember Me"),
                ],
              ),

              if (!_isLogin) ...[
                const SizedBox(height: 15),
                const Text("Sign up as:"),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Radio(value: 'student', groupValue: _role, onChanged: (v) => setState(() => _role = v!)),
                    const Text("Student"),
                    Radio(value: 'teacher', groupValue: _role, onChanged: (v) => setState(() => _role = v!)),
                    const Text("Teacher"),
                  ],
                )
              ],
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3182CE), foregroundColor: Colors.white),
                  onPressed: _submit,
                  child: Text(_isLogin ? "LOGIN" : "REGISTER"))
              ),

              TextButton(onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(_isLogin ? "Don't have an account? Register" : "Already have an account? Login")),

              if (_isLogin) TextButton(onPressed: _resetPassword, child: const Text("Forgot Password?")),
            ],
          ),
        ),
      ),
    );
  }
}