import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/attendance_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart'; // NEW: For Native Local Saving
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io'; // Needed for File and Directory access
import 'package:flutter/foundation.dart' show kIsWeb; // Needed to prevent crashes on Web

class TeacherRemoteScreen extends StatefulWidget {
  const TeacherRemoteScreen({super.key});
  @override
  State<TeacherRemoteScreen> createState() => _TeacherRemoteScreenState();
}

class _TeacherRemoteScreenState extends State<TeacherRemoteScreen> {
  final AttendanceService _service = AttendanceService();
  final _codeController = TextEditingController();
  final _classNameController = TextEditingController();

  bool _isLinked = false;
  bool _isBroadcasting = false;
  bool _isLoading = false;

  bool _isAutoStopMode = false;
  int _rotationSeconds = 15;

  void _handleExit() async {
    if (_isBroadcasting) _service.stopBroadcasting(_codeController.text);
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  void _link() async {
    if (_codeController.text.length == 4 && _classNameController.text.isNotEmpty) {
      setState(() => _isLoading = true);
      bool success = await _service.linkRemoteToDisplay(_codeController.text, _classNameController.text);
      if (mounted) {
        setState(() { _isLinked = success; _isLoading = false; });
        if (success) {
          FocusScope.of(context).unfocus();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid code! Is the web projector open?")));
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a Class Name and 4-Digit Code.")));
    }
  }

  Future<void> _printPDF(List<QueryDocumentSnapshot> docs) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Attendance: ${_classNameController.text}", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text("Date: ${DateTime.now().toString().split(' ')[0]}", style: pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 20),
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Text("- ${data['studentName']} (${data['studentEmail'] ?? 'No email'})", style: pw.TextStyle(fontSize: 16)),
                );
              }),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Future<void> _exportExcel(List<QueryDocumentSnapshot> docs) async {
    List<List<dynamic>> rows = [];
    rows.add(["Student Name", "Email", "Status", "Time"]);

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      rows.add([
        data['studentName'] ?? "Unknown",
        data['studentEmail'] ?? "No Email",
        "Present",
        (data['timestamp'] as Timestamp?)?.toDate().toString() ?? "Unknown Time",
      ]);
    }

    String csvStr = const ListToCsvConverter().convert(rows);
    Uint8List bytes = Uint8List.fromList(utf8.encode(csvStr));

    try {
      String savedPath = "";

      // Fetch the teacher's name
      String rawTeacherName = FirebaseAuth.instance.currentUser?.displayName ?? "Teacher";

      // Remove any illegal characters that file systems hate (like / \ : * ? " < > |)
      String safeTeacherName = rawTeacherName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      String safeClassName = _classNameController.text.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

      // The new base filename: teacher__classroom name
      String baseFileName = '${safeTeacherName}__$safeClassName';

      // --- Android Direct Download Logic ---
      if (!kIsWeb && Platform.isAndroid) {
        Directory dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) dir = Directory('/storage/emulated/0/Downloads');

        // Adds a timestamp to prevent overwriting previous files of the exact same name
        String fileName = '${baseFileName}_${DateTime.now().millisecondsSinceEpoch}.csv';
        File file = File('${dir.path}/$fileName');

        await file.writeAsBytes(bytes);
        savedPath = file.path;
      }
      // --- iOS and Web Logic (File Saver) ---
      else {
        savedPath = await FileSaver.instance.saveFile(
          name: baseFileName,
          bytes: bytes,
          fileExtension: 'csv',
          mimeType: MimeType.csv,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Saved directly to: $savedPath"),
              duration: const Duration(seconds: 5),
              backgroundColor: Colors.green,
            )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving file: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Teacher Remote"),
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            onSelected: (value) => value == 'logout' ? _handleExit() : null,
            itemBuilder: (context) => [const PopupMenuItem(value: 'logout', child: Text("Logout"))],
          ),
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.red),
            onPressed: () => SystemChannels.platform.invokeMethod('SystemNavigator.pop'),
          ),
        ],
      ),
      body: _isLinked ? _buildDashboard() : _buildPairing(),
    );
  }

  Widget _buildPairing() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Create a Classroom", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextField(
            controller: _classNameController,
            decoration: const InputDecoration(labelText: "Class Name (e.g., Math 101)", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _codeController,
            maxLength: 4,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Enter 4-Digit Projector Code", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          if (_isLoading) const CircularProgressIndicator()
          else ElevatedButton(
            onPressed: _link,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            child: const Text("CONNECT & START"),
          ),
          const SizedBox(height: 40),
          const Divider(),
          const Text("Recent Attendances (Last 15)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildRecentSessions(),
        ],
      ),
    );
  }

  // --- NEW: Recent Sessions List ---
  Widget _buildRecentSessions() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      // Fetches all sessions created by this teacher
      stream: FirebaseFirestore.instance
          .collection('sessions')
          .where('teacherId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        var docs = snapshot.data!.docs;

        // Sort locally to prevent requiring manual Firestore Indexes
        docs.sort((a, b) {
          var aTime = (a.data() as Map<String, dynamic>)['lastHeartbeat'] as Timestamp?;
          var bTime = (b.data() as Map<String, dynamic>)['lastHeartbeat'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        var recentDocs = docs.take(15).toList();

        if (recentDocs.isEmpty) return const Text("No recent classrooms found.", style: TextStyle(color: Colors.grey));

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recentDocs.length,
          itemBuilder: (context, index) {
            var data = recentDocs[index].data() as Map<String, dynamic>;
            bool isFinished = data['status'] == 'finished' || data['status'] == 'stopped';

            return Card(
              child: ListTile(
                leading: Icon(isFinished ? Icons.history : Icons.sensors, color: isFinished ? Colors.grey : Colors.green),
                title: Text(data['className'] ?? "Classroom", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Status: ${data['status'].toString().toUpperCase()} \nCode: ${recentDocs[index].id}"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // Allows the teacher to click and re-open the dashboard to view/export the list!
                  setState(() {
                    _codeController.text = recentDocs[index].id;
                    _classNameController.text = data['className'] ?? "Classroom";
                    _isLinked = true;
                    _isBroadcasting = false; // Opens in paused state by default
                  });
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDashboard() {
    return Column(
      children: [
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _isLinked = false), // Go back to Recent list
            ),
            Text("Class: ${_classNameController.text}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
          ],
        ),
        const SizedBox(height: 10),

        const Text("QR Behavior Mode:", style: TextStyle(fontWeight: FontWeight.bold)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChoiceChip(
              label: const Text("Rotate Code"),
              selected: !_isAutoStopMode,
              onSelected: _isBroadcasting ? null : (v) => setState(() => _isAutoStopMode = false),
            ),
            const SizedBox(width: 10),
            ChoiceChip(
              label: const Text("Auto-Turn Off"),
              selected: _isAutoStopMode,
              selectedColor: Colors.orangeAccent,
              onSelected: _isBroadcasting ? null : (v) => setState(() => _isAutoStopMode = true),
            ),
          ],
        ),

        const SizedBox(height: 10),
        Text("Time limit: $_rotationSeconds seconds", style: const TextStyle(fontWeight: FontWeight.bold)),
        Slider(
          value: _rotationSeconds.toDouble(),
          min: 5, max: 120, divisions: 23,
          label: "$_rotationSeconds sec",
          onChanged: _isBroadcasting ? null : (v) => setState(() => _rotationSeconds = v.toInt()),
        ),

        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _isBroadcasting ? Colors.red : Colors.green,
            foregroundColor: Colors.white,
            minimumSize: const Size(200, 50),
          ),
          onPressed: () {
            if (_isBroadcasting) {
              _service.stopBroadcasting(_codeController.text);
              setState(() => _isBroadcasting = false);
            } else {
              setState(() => _isBroadcasting = true);
              _service.startBroadcasting(
                  _codeController.text,
                  seconds: _rotationSeconds,
                  autoStop: _isAutoStopMode,
                  onAutoStop: () {
                    if (mounted) setState(() => _isBroadcasting = false);
                  }
              );
            }
          },
          child: Text(_isBroadcasting ? "STOP ATTENDANCE" : "START ATTENDANCE", style: const TextStyle(fontSize: 18)),
        ),
        const Divider(height: 10),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('sessions')
                .doc(_codeController.text)
                .collection('attendance')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final docs = snapshot.data!.docs;

              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: docs.isEmpty ? null : () => _printPDF(docs),
                        icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                        label: const Text("PDF", style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      ),
                      ElevatedButton.icon(
                        onPressed: docs.isEmpty ? null : () => _exportExcel(docs),
                        icon: const Icon(Icons.table_chart, color: Colors.white),
                        label: const Text("Excel", style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text("Students in Classroom: ${docs.length}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        var data = docs[index].data() as Map<String, dynamic>;
                        return ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(data['studentName'] ?? "Student"),
                          subtitle: Text(data['studentEmail'] ?? ""),
                          trailing: IconButton(
                            icon: const Icon(Icons.person_remove, color: Colors.red),
                            tooltip: "Kick Student",
                            onPressed: () {
                              _service.kickStudent(_codeController.text, docs[index].id);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: () async {
                        await _service.finishSession(_codeController.text);
                        setState(() {
                          _isLinked = false;
                          _isBroadcasting = false;
                          _codeController.clear();
                          _classNameController.clear();
                        });
                      },
                      icon: const Icon(Icons.done_all, color: Colors.white),
                      label: const Text("FINISH CLASSROOM", style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}