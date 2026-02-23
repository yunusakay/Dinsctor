import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/attendance_service.dart';

class WebLandingScreen extends StatefulWidget {
  const WebLandingScreen({super.key});

  @override
  State<WebLandingScreen> createState() => _WebLandingScreenState();
}

class _WebLandingScreenState extends State<WebLandingScreen> {
  final AttendanceService _service = AttendanceService();
  String? _displayCode;

  @override
  void initState() {
    super.initState();
    _setupDisplay();
  }

  void _setupDisplay() async {
    String code = await _service.initWebDisplay();
    setState(() => _displayCode = code);
  }

  @override
  Widget build(BuildContext context) {
    if (_displayCode == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFF1A202C),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('sessions').doc(
            _displayCode).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          var data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          String status = data['status'] ?? 'waiting';

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (status == 'waiting') ...[
                  const Text("Projector Ready",
                      style: TextStyle(color: Colors.white70, fontSize: 24)),
                  const SizedBox(height: 20),
                  Text(_displayCode!, style: const TextStyle(
                      color: Colors.white,
                      fontSize: 120,
                      fontWeight: FontWeight.bold)),
                ] else
                  ...[
                    _buildActiveSessionUI(data), // Fixed: Called helper UI
                  ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveSessionUI(Map<String, dynamic> data) {
    String token = data['currentToken'] ?? '';
    String teacher = data['teacherName'] ?? 'Teacher';
    String className = data['className'] ?? 'Classroom';
    String displayCode = data['displayCode'] ?? '----'; // Fetches the projector code

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (token.isNotEmpty) ...[
          // --- Active State: Shows QR Code, Class, and Teacher ---
          Text(className, style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
          Text("Instructor: $teacher", style: const TextStyle(color: Colors.white70, fontSize: 28)),
          const SizedBox(height: 30),

          const Text("SCAN TO MARK ATTENDANCE", style: TextStyle(color: Colors.white, fontSize: 32)),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: QrImageView(data: token, size: 300),
          ),
        ] else ...[
    // --- Paused/Stopped State: Shows the Room Code ---
    const Icon(Icons.meeting_room, color: Colors.blueAccent, size: 80),
    const SizedBox(height: 20),
    // FIXED: Changed from ROOM CODE to PROJECTOR CODE
    const Text("PROJECTOR CODE", style: TextStyle(color: Colors.white70, fontSize: 28, letterSpacing: 5)),
    const SizedBox(height: 10),
    Text(
    displayCode,
    style: const TextStyle(color: Colors.white, fontSize: 120, fontWeight: FontWeight.bold, letterSpacing: 25)
    ),
    const SizedBox(height: 20),
    const Text("Waiting for teacher to start attendance...", style: TextStyle(color: Colors.white54, fontSize: 24)),
    ],
    ]
    );
  }
}