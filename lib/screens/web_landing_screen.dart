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
    if (_displayCode == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFF1A202C), // Dark Professional background
      body: StreamBuilder<DocumentSnapshot>(// Inside your StreamBuilder builder function:
      var data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
      String status = data['status'] ?? 'waiting';

    return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (status == 'waiting') ...[
          // Only show the code, NO buttons
          const Text("Projector Ready", style: TextStyle(color: Colors.white70, fontSize: 24)),
          const SizedBox(height: 20),
          Text(_displayCode!, style: const TextStyle(color: Colors.white, fontSize: 120, fontWeight: FontWeight.bold)),
        ] else if (status == 'linked' || status == 'active') ...[
          // As soon as the teacher connects, the code vanishes!
          _buildActiveSessionUI(data),
        ],
      ],
    ),
    );
      ),
    );
  }
}