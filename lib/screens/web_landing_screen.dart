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
    setState(() => _displayCode = null); // Trigger loading circle
    String code = await _service.initWebDisplay();
    setState(() => _displayCode = code);
  }

  @override
  Widget build(BuildContext context) {
    if (_displayCode == null) {
      return const Scaffold(backgroundColor: Color(0xFF0F172A), body: Center(child: CircularProgressIndicator(color: Colors.cyan)));
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          ),
        ),
        child: Stack(
          children: [
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('sessions').doc(_displayCode).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Colors.cyan));
                }

                var data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                String status = data['status'] ?? 'waiting';

                // FIXED: Auto-reset projector code if the teacher hits "Finish Classroom"
                if (status == 'finished') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _setupDisplay();
                  });
                  return const Center(child: CircularProgressIndicator(color: Colors.cyan));
                }

                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (status == 'waiting') ...[
                          const Icon(Icons.cast_connected, color: Colors.cyanAccent, size: 80),
                          const SizedBox(height: 24),
                          const Text("PROJECTOR READY", style: TextStyle(color: Colors.cyanAccent, fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 20),
                          Text(
                              _displayCode!,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 140,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 30,
                                  shadows: [Shadow(color: Colors.cyan, blurRadius: 40)]
                              )
                          ),
                          const SizedBox(height: 20),
                          const Text("Enter this code in the Teacher App to begin.", style: TextStyle(color: Colors.white54, fontSize: 24)),
                        ] else ...[
                          _buildActiveSessionUI(data),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),

            // FIXED: Manual reset button in case a teacher force-closed app without finishing
            Positioned(
              bottom: 30,
              right: 30,
              child: Tooltip(
                message: "Reset Projector Code",
                child: FloatingActionButton(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  elevation: 0,
                  onPressed: _setupDisplay,
                  child: const Icon(Icons.refresh, color: Colors.white70),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSessionUI(Map<String, dynamic> data) {
    String token = data['currentToken'] ?? '';
    String teacher = data['teacherName'] ?? 'Teacher';
    String className = data['className'] ?? 'Classroom';
    String displayCode = data['displayCode'] ?? '----';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (token.isNotEmpty) ...[
          Text(className.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 8),
          Text("Instructor: $teacher", style: const TextStyle(color: Colors.cyanAccent, fontSize: 28)),
          const SizedBox(height: 40),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(color: Colors.cyanAccent.withOpacity(0.3), blurRadius: 60, spreadRadius: 10),
              ],
            ),
            child: QrImageView(data: token, size: 300, backgroundColor: Colors.white),
          ),
          const SizedBox(height: 40),
          const Text("SCAN WITH STUDENT APP", style: TextStyle(color: Colors.white, fontSize: 28, letterSpacing: 4, fontWeight: FontWeight.bold)),

        ] else ...[
          const Icon(Icons.meeting_room_rounded, color: Colors.redAccent, size: 100),
          const SizedBox(height: 24),
          const Text("SESSION PAUSED", style: TextStyle(color: Colors.redAccent, fontSize: 28, letterSpacing: 8, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Text(
              displayCode,
              style: const TextStyle(color: Colors.white, fontSize: 120, fontWeight: FontWeight.w900, letterSpacing: 30)
          ),
          const SizedBox(height: 20),
          const Text("Waiting for teacher to resume attendance...", style: TextStyle(color: Colors.white54, fontSize: 24)),
        ],
      ],
    );
  }
}