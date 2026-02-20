import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/attendance_service.dart';

class StudentScreen extends StatefulWidget {
  const StudentScreen({super.key});

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> {
  final AttendanceService _service = AttendanceService();
  bool _isProcessing = false;

  // Exit/Logout Function
  void _handleExit() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? scannedToken = barcodes.first.rawValue;
      if (scannedToken != null) {
        setState(() => _isProcessing = true);

        // Use current user's email or "Student" as display name
        String studentEmail = FirebaseAuth.instance.currentUser?.email ??
            "Unknown Student";
        bool success = await _service.submitAttendance(
            scannedToken, studentEmail);

        if (mounted) {
          _showResult(success);
        }
      }
    }
  }

  void _showResult(bool success) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          AlertDialog(
            title: Icon(success ? Icons.check_circle : Icons.error,
                color: success ? Colors.green : Colors.red, size: 60),
            content: Text(
                success ? "Attendance Marked!" : "Invalid or Expired QR code.",
                textAlign: TextAlign.center),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => _isProcessing = false);
                },
                child: const Text("OK"),
              )
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Scanner"),
        backgroundColor: const Color(0xFF2D3748),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleExit,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          // Frame overlay logic stays here...
        ],
      ),
    );
  }
}