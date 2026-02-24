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
  final _nameController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  String _role = 'student';

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  void _checkExistingSession() async {
    final user = _auth.currentUser;
    if (user != null) {
      _navigateBasedOnRole(user.uid);
    } else {
      _loadSavedEmail();
    }
  }

  void _loadSavedEmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _emailController.text = prefs.getString('saved_email') ?? "";
      _rememberMe = _emailController.text.isNotEmpty;
    });
  }

  void _navigateBasedOnRole(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists && mounted) {
      String role = doc.get('role');
      Navigator.pushReplacementNamed(context, role == 'teacher' ? '/teacher' : '/student');
    }
  }

  // --- RESTORED: Reset Password Logic ---
  // --- FIXED: Renamed local variable, fixed async gaps ---
  void _resetPassword() async {
    final TextEditingController resetEmailController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Reset Password", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            TextField(controller: resetEmailController, decoration: const InputDecoration(labelText: "Email")),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _auth.sendPasswordResetEmail(email: resetEmailController.text.trim());
                  if (!context.mounted) return; // FIXED ASYNC GAP
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reset link sent!")));
                } catch (e) {
                  if (!context.mounted) return; // FIXED ASYNC GAP
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              child: const Text("Send Link"),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- FIXED: Async Gaps in Submit ---
  Future<void> _submit() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;
    if (!_isLogin && _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Name is required")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('saved_email', _emailController.text.trim());
      } else {
        await prefs.remove('saved_email');
      }

      if (_isLogin) {
        final cred = await _auth.signInWithEmailAndPassword(
            email: _emailController.text.trim(), password: _passwordController.text.trim());
        _navigateBasedOnRole(cred.user!.uid);
      } else {
        final cred = await _auth.createUserWithEmailAndPassword(
            email: _emailController.text.trim(), password: _passwordController.text.trim());

        await cred.user!.updateDisplayName(_nameController.text.trim());
        await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
          'name': _nameController.text.trim(),
          'role': _role,
          'email': _emailController.text.trim(),
        });
        _navigateBasedOnRole(cred.user!.uid);
      }
    } catch (e) {
      if (!mounted) return; // FIXED ASYNC GAP
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser != null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Text("Dinsctor", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF3182CE))),
              const SizedBox(height: 40),
              if (!_isLogin) ...[
                TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder())),
                const SizedBox(height: 15),
                const Text("Account Type:"),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Radio(value: 'student', groupValue: _role, onChanged: (v) => setState(() => _role = v!)),
                    const Text("Student"),
                    Radio(value: 'teacher', groupValue: _role, onChanged: (v) => setState(() => _role = v!)),
                    const Text("Teacher"),
                  ],
                ),
              ],
              TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder())),
              const SizedBox(height: 15),
              TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder())),
              CheckboxListTile(
                title: const Text("Remember Me"),
                value: _rememberMe,
                onChanged: (v) => setState(() => _rememberMe = v!),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 20),
              _isLoading ? const CircularProgressIndicator() : SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _submit, child: Text(_isLogin ? "LOGIN" : "REGISTER"))),
              TextButton(onPressed: () => setState(() => _isLogin = !_isLogin), child: Text(_isLogin ? "Need an account? Register" : "Have an account? Login")),
              // --- RESTORED: Forgot Password Button ---
              if (_isLogin) TextButton(onPressed: _resetPassword, child: const Text("Forgot Password?")),
            ],
          ),
        ),
      ),
    );
  }
}