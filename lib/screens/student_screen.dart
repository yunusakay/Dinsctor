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
  bool _isLeaving = false;
  String? _activeSessionId;

  void _handleExit() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? scannedToken = barcodes.first.rawValue;
      if (scannedToken != null) {
        setState(() => _isProcessing = true);

        String studentName = FirebaseAuth.instance.currentUser?.displayName ?? "Öğrenci";
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Icon(success ? Icons.check_circle : Icons.error,
            color: success ? Colors.green : Colors.red, size: 60),
        content: Text(
            success ? "Yoklama Alındı!" : "Geçersiz veya Süresi Dolmuş QR kod.",
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: success ? Colors.green : Colors.red, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(context);
                setState(() => _isProcessing = false);
              },
              child: const Text("TAMAM"),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Öğrenci Paneli", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.logout, color: Colors.white70), onPressed: _handleExit),
          IconButton(icon: const Icon(Icons.power_settings_new, color: Colors.redAccent), onPressed: () => SystemChannels.platform.invokeMethod('SystemNavigator.pop')),
        ],
      ),
      body: _activeSessionId == null
          ? _buildScannerView()
          : _buildClassroomView(),
    );
  }

  Widget _buildScannerView() {
    return Stack(
      children: [
        MobileScanner(onDetect: _onDetect),
        Container(color: Colors.black.withOpacity(0.5)),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("SINIF QR KODUNU TARA", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 30),
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.cyanAccent, width: 4),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.3), blurRadius: 20, spreadRadius: 5)],
                ),
              ),
              const SizedBox(height: 30),
              const Text("Projektördeki kodu çerçevenin içine hizalayın", style: TextStyle(color: Colors.white70, fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClassroomView() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('sessions').doc(_activeSessionId).snapshots(),
      builder: (context, sessionSnapshot) {
        if (!sessionSnapshot.hasData) return const Center(child: CircularProgressIndicator());

        var sessionData = sessionSnapshot.data!.data() as Map<String, dynamic>?;

        // --- FIXED: Teacher Finished Classroom Logic ---
        if (sessionData?['status'] == 'finished') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _activeSessionId != null) {
              setState(() {
                _activeSessionId = null;
                _isLeaving = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Ders öğretmen tarafından sonlandırıldı."),
                backgroundColor: Colors.blue,
              ));
            }
          });
          return const Center(child: CircularProgressIndicator()); // Returns to scanner silently
        }
        // ------------------------------------------------

        String teacherName = sessionData?['teacherName'] ?? "Öğretmen";
        String className = sessionData?['className'] ?? "Sınıf";

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: const BoxDecoration(
                color: Color(0xFF4F46E5),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.school, size: 60, color: Colors.white),
                  const SizedBox(height: 16),
                  Text(className, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text("Öğretmen: $teacherName", style: const TextStyle(fontSize: 16, color: Colors.white70)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: () async {
                      setState(() => _isLeaving = true);
                      await _service.leaveClassroom(_activeSessionId!);
                      if (mounted) setState(() { _activeSessionId = null; _isLeaving = false; });
                    },
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text("Sınıftan Ayrıl", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.all(20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("Sınıftakiler", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('sessions').doc(_activeSessionId).collection('attendance').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  final students = snapshot.data!.docs;
                  final myUid = FirebaseAuth.instance.currentUser?.uid;

                  bool amIStillInClass = students.any((doc) => (doc.data() as Map<String, dynamic>)['studentId'] == myUid);
                  if (!amIStillInClass && snapshot.connectionState == ConnectionState.active) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && !_isLeaving && _activeSessionId != null) {
                        setState(() => _activeSessionId = null);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Öğretmen tarafından dersten çıkarıldınız."), backgroundColor: Colors.red));
                      }
                    });
                    if (!_isLeaving) return const Center(child: CircularProgressIndicator());
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      var data = students[index].data() as Map<String, dynamic>;
                      bool isMe = data['studentId'] == myUid;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isMe ? const Color(0xFF4F46E5).withOpacity(0.2) : Colors.grey.shade200,
                            child: Icon(Icons.person, color: isMe ? const Color(0xFF4F46E5) : Colors.grey),
                          ),
                          title: Text(data['studentName'] ?? "İsimsiz", style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.normal)),
                          trailing: const Icon(Icons.check_circle, color: Colors.green),
                        ),
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