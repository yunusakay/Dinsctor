import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/attendance_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

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
        if (success) FocusScope.of(context).unfocus();
        else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Geçersiz kod!"), backgroundColor: Colors.redAccent));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen bir Sınıf Adı ve 4 Haneli Kod girin.")));
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
              pw.Text("Yoklama: ${_classNameController.text}", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text("Tarih: ${DateTime.now().toString().split(' ')[0]}", style: pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 20),
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Text("- ${data['studentName']} (${data['studentEmail'] ?? 'E-posta Yok'})", style: pw.TextStyle(fontSize: 16)),
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
    List<List<dynamic>> rows = [["Öğrenci Adı", "E-posta", "Durum", "Saat"]];
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      rows.add([
        data['studentName'] ?? "Bilinmeyen",
        data['studentEmail'] ?? "E-posta Yok",
        "Mevcut",
        (data['timestamp'] as Timestamp?)?.toDate().toString() ?? "Bilinmeyen Saat",
      ]);
    }
    String csvStr = const ListToCsvConverter().convert(rows);
    Uint8List bytes = Uint8List.fromList(utf8.encode(csvStr));

    try {
      String savedPath = "";
      String safeTeacherName = (FirebaseAuth.instance.currentUser?.displayName ?? "Öğretmen").replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      String safeClassName = _classNameController.text.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      String baseFileName = '${safeTeacherName}__$safeClassName';

      if (!kIsWeb && Platform.isAndroid) {
        Directory dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) dir = Directory('/storage/emulated/0/Downloads');
        DateTime now = DateTime.now();
        String cleanDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}";
        File file = File('${dir.path}/${baseFileName}_$cleanDate.csv');
        await file.writeAsBytes(bytes);
        savedPath = file.path;
      } else {
        savedPath = await FileSaver.instance.saveFile(name: baseFileName, bytes: bytes, fileExtension: 'csv', mimeType: MimeType.csv);
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Kaydedildi: $savedPath"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Öğretmen Paneli", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.logout, color: Colors.white70), onPressed: _handleExit),
          IconButton(icon: const Icon(Icons.power_settings_new, color: Colors.redAccent), onPressed: () => SystemChannels.platform.invokeMethod('SystemNavigator.pop')),
        ],
      ),
      body: _isLinked ? _buildDashboard() : _buildPairing(),
    );
  }

  Widget _buildPairing() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Sınıf Oluştur", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                const SizedBox(height: 8),
                const Text("Uygulamanızı Web Projektörüne bağlayın", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                TextField(
                  controller: _classNameController,
                  decoration: const InputDecoration(labelText: "Sınıf Adı (örn. Mat 101)", prefixIcon: Icon(Icons.school_outlined)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                  decoration: const InputDecoration(labelText: "4 Haneli Projektör Kodu", prefixIcon: Icon(Icons.cast_connected)),
                ),
                const SizedBox(height: 16),
                if (_isLoading) const Center(child: CircularProgressIndicator())
                else ElevatedButton(
                  onPressed: _link,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 54)),
                  child: const Text("BAĞLAN & BAŞLAT", style: TextStyle(fontSize: 16, letterSpacing: 1)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text("Geçmiş Yoklamalar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 16),
          _buildRecentSessions(),
        ],
      ),
    );
  }

  Widget _buildRecentSessions() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('sessions').where('teacherId', isEqualTo: uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var docs = snapshot.data!.docs;
        docs.sort((a, b) {
          var aTime = (a.data() as Map<String, dynamic>)['lastHeartbeat'] as Timestamp?;
          var bTime = (b.data() as Map<String, dynamic>)['lastHeartbeat'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        var recentDocs = docs.take(15).toList();
        if (recentDocs.isEmpty) return const Text("Geçmiş sınıf bulunamadı.", style: TextStyle(color: Colors.grey));

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recentDocs.length,
          itemBuilder: (context, index) {
            var data = recentDocs[index].data() as Map<String, dynamic>;
            bool isFinished = data['status'] == 'finished' || data['status'] == 'stopped';

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: isFinished ? Colors.grey.shade200 : const Color(0xFF06B6D4).withOpacity(0.2),
                  child: Icon(isFinished ? Icons.history : Icons.sensors, color: isFinished ? Colors.grey : const Color(0xFF06B6D4)),
                ),
                title: Text(data['className'] ?? "Sınıf", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Durum: ${data['status'].toString().toUpperCase()} \nKod: ${recentDocs[index].id}"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                onTap: () {
                  setState(() {
                    _codeController.text = recentDocs[index].id;
                    _classNameController.text = data['className'] ?? "Sınıf";
                    _isLinked = true;
                    _isBroadcasting = false;
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
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFF4F46E5)), onPressed: () => setState(() => _isLinked = false)),
                  Expanded(child: Text(_classNameController.text, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)))),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ChoiceChip(
                    label: const Text("Kodu Değiştir"),
                    selected: !_isAutoStopMode,
                    selectedColor: const Color(0xFF4F46E5).withOpacity(0.2),
                    onSelected: _isBroadcasting ? null : (v) => setState(() => _isAutoStopMode = false),
                  ),
                  ChoiceChip(
                    label: const Text("Otomatik Kapanma"),
                    selected: _isAutoStopMode,
                    selectedColor: Colors.orangeAccent.withOpacity(0.2),
                    onSelected: _isBroadcasting ? null : (v) => setState(() => _isAutoStopMode = true),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.grey),
                  Expanded(
                    child: Slider(
                      value: _rotationSeconds.toDouble(),
                      activeColor: const Color(0xFF4F46E5),
                      min: 5, max: 120, divisions: 23,
                      label: "$_rotationSeconds sn",
                      onChanged: _isBroadcasting ? null : (v) => setState(() => _rotationSeconds = v.toInt()),
                    ),
                  ),
                  Text("${_rotationSeconds}sn", style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isBroadcasting ? Colors.redAccent : Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                ),
                icon: Icon(_isBroadcasting ? Icons.pause : Icons.play_arrow),
                label: Text(_isBroadcasting ? "YOKLAMAYI DURDUR" : "YOKLAMAYI BAŞLAT", style: const TextStyle(letterSpacing: 1)),
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
                        onAutoStop: () { if (mounted) setState(() => _isBroadcasting = false); }
                    );
                  }
                },
              ),
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('sessions').doc(_codeController.text).collection('attendance').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Mevcut: ${docs.length}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                        Row(
                          children: [
                            IconButton(
                              onPressed: docs.isEmpty ? null : () => _printPDF(docs),
                              icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                              tooltip: "PDF'e Aktar",
                            ),
                            IconButton(
                              onPressed: docs.isEmpty ? null : () => _exportExcel(docs),
                              icon: const Icon(Icons.table_chart, color: Colors.green),
                              tooltip: "Excel'e Aktar",
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        var data = docs[index].data() as Map<String, dynamic>;
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                          child: ListTile(
                            leading: CircleAvatar(backgroundColor: Colors.grey.shade100, child: const Icon(Icons.person, color: Colors.grey)),
                            title: Text(data['studentName'] ?? "Öğrenci", style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(data['studentEmail'] ?? "", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                              tooltip: "Öğrenciyi Çıkar",
                              onPressed: () => _service.kickStudent(_codeController.text, docs[index].id),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F2937), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 54)),
                      onPressed: () async {
                        await _service.finishSession(_codeController.text);
                        setState(() { _isLinked = false; _isBroadcasting = false; _codeController.clear(); _classNameController.clear(); });
                      },
                      icon: const Icon(Icons.done_all),
                      label: const Text("SINIFI BİTİR VE KAPAT"),
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