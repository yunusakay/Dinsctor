import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  String? _activeSessionId;

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

        String studentName = FirebaseAuth.instance.currentUser?.displayName ?? "Student";

        bool success = await _service.submitAttendance(scannedToken, studentName);

        if (mounted) {
          if (success) {
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
            onPressed: () => SystemChannels.platform.invokeMethod('SystemNavigator.pop'),
          ),
        ],
      ),
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
          const Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Text(
              "Scan QR code to join class",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          )
        ],
      )
          : _buildClassroomView(),
    );
  }

  Widget _buildClassroomView() {
    return StreamBuilder<DocumentSnapshot>(
      // Get Teacher's Name from the Session Document
      stream: FirebaseFirestore.instance.collection('sessions').doc(_activeSessionId).snapshots(),
      builder: (context, sessionSnapshot) {
        if (!sessionSnapshot.hasData) return const Center(child: CircularProgressIndicator());

        var sessionData = sessionSnapshot.data!.data() as Map<String, dynamic>?;
        String teacherName = sessionData?['teacherName'] ?? "Teacher";

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: Colors.blueGrey.shade50,
              child: Column(
                children: [
                  Text("Instructor: $teacherName",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () async {
                      // Actually removes them from the database list
                      await _service.leaveClassroom(_activeSessionId!);
                      setState(() => _activeSessionId = null); // Returns to scanner
                    },
                    icon: const Icon(Icons.exit_to_app, color: Colors.orange),
                    label: const Text("Leave Classroom", style: TextStyle(color: Colors.orange)),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text("Classmates Present", style: TextStyle(fontSize: 16, color: Colors.grey)),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // Get Attendee List
                stream: FirebaseFirestore.instance
                    .collection('sessions')
                    .doc(_activeSessionId)
                    .collection('attendance')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  final students = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      var data = students[index].data() as Map<String, dynamic>;
                      return ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(data['studentName'] ?? "Anonymous"),
                        trailing: const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}