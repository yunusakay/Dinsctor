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

  void _resetPassword() async {
    final TextEditingController resetEmailController = TextEditingController();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Reset Password", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Enter your email and we will send you a reset link.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            TextField(
              controller: resetEmailController,
              decoration: const InputDecoration(labelText: "Email Address", prefixIcon: Icon(Icons.email_outlined)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _auth.sendPasswordResetEmail(email: resetEmailController.text.trim());
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reset link sent!"), backgroundColor: Colors.green));
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
              child: const Text("Send Reset Link"),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser != null) {
      return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)], // Indigo to Cyan gradient
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo / Icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded, size: 80, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  const Text("Dinsctor", style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
                  const Text("Smart Classroom Attendance", style: TextStyle(fontSize: 16, color: Colors.white70)),
                  const SizedBox(height: 40),

                  // Floating Glass Card
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(_isLogin ? "Welcome Back" : "Create Account",
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                        const SizedBox(height: 24),

                        if (!_isLogin) ...[
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: "Full Name", prefixIcon: Icon(Icons.person_outline)),
                          ),
                          const SizedBox(height: 16),
                          const Text("Account Type:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _role = 'student'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _role == 'student' ? const Color(0xFF4F46E5).withOpacity(0.1) : Colors.transparent,
                                      border: Border.all(color: _role == 'student' ? const Color(0xFF4F46E5) : Colors.grey.shade300, width: 2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(child: Text("Student", style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _role == 'student' ? const Color(0xFF4F46E5) : Colors.grey
                                    ))),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _role = 'teacher'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _role == 'teacher' ? const Color(0xFF4F46E5).withOpacity(0.1) : Colors.transparent,
                                      border: Border.all(color: _role == 'teacher' ? const Color(0xFF4F46E5) : Colors.grey.shade300, width: 2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(child: Text("Teacher", style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _role == 'teacher' ? const Color(0xFF4F46E5) : Colors.grey
                                    ))),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email_outlined)),
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock_outline)),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: _rememberMe,
                                  activeColor: const Color(0xFF4F46E5),
                                  onChanged: (v) => setState(() => _rememberMe = v ?? false),
                                ),
                                const Text("Remember me", style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                            if (_isLogin)
                              TextButton(
                                onPressed: _resetPassword,
                                child: const Text("Forgot Password?", style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            shadowColor: const Color(0xFF4F46E5).withOpacity(0.5),
                            elevation: 8,
                          ),
                          child: Text(_isLogin ? "LOG IN" : "SIGN UP"),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin ? "Don't have an account? Sign up" : "Already have an account? Log in",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}