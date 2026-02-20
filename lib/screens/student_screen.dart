import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Fixed: Required for SystemChannels
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Required for Classroom List
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
  String? _activeSessionId; // Tracks the session the student joined

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

        // Uses the real name saved during registration
        String studentName = FirebaseAuth.instance.currentUser?.displayName ?? "Student";

        bool success = await _service.submitAttendance(scannedToken, studentName);

        if (mounted) {
          if (success) {
            // Find the session ID from the token to show the list
            final snapshot = await FirebaseFirestore.instance
                .collection('sessions')
                .where('currentToken', isEqualTo: scannedToken)
                .limit(1)
                .get();

            if (snapshot.docs.isNotEmpty) {
              setState(() => _activeSessionId = snapshot.docs.first.id);
            }
          }
          _showResult(success);
        }
      }
    }
  }

  void _showResult(bool success) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
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
        title: const Text("Student Panel"),
        backgroundColor: const Color(0xFF2D3748),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            onSelected: (value) => value == 'logout' ? _handleExit() : null,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'logout', child: Text("Logout")),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.red),
            onPressed: () => SystemChannels.platform.invokeMethod('SystemNavigator.pop'), // Fixed
          ),
        ],
      ),
      // Toggle between Scanner and Classroom List
      body: _activeSessionId == null
          ? Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      )
          : _buildClassroomList(),
    );
  }

  Widget _buildClassroomList() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("Classroom Attendees", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('sessions')
                .doc(_activeSessionId)
                .collection('attendance')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(data['studentName'] ?? "Anonymous"),
                    trailing: const Text("Checked In", style: TextStyle(color: Colors.green, fontSize: 12)),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}