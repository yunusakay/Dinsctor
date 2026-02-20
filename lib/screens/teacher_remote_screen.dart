import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for SystemNavigator.pop
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/attendance_service.dart';

class TeacherRemoteScreen extends StatefulWidget {
  const TeacherRemoteScreen({super.key});
  @override
  State<TeacherRemoteScreen> createState() => _TeacherRemoteScreenState();
}

class _TeacherRemoteScreenState extends State<TeacherRemoteScreen> {
  final AttendanceService _service = AttendanceService();
  final _codeController = TextEditingController();
  bool _isLinked = false;
  bool _isBroadcasting = false;
  int _rotationSeconds = 7; // Default security rotation time

  void _handleExit() async {
    if (_isBroadcasting) {
      _service.stopBroadcasting(_codeController.text);
    }
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Teacher Remote"),
        automaticallyImplyLeading: false,
        actions: [
          // NEW: Language Selection Button (Left of user icon)
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            onSelected: (lang) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(lang == 'en' ? "Language: English" : "Dil: Türkçe")),
              );
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'en', child: Text("English")),
              const PopupMenuItem(value: 'tr', child: Text("Türkçe")),
            ],
          ),
          // Account Popup
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            onSelected: (value) => value == 'logout' ? _handleExit() : null,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'logout', child: Text("Logout")),
            ],
          ),
          // Direct Exit App Button
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.red),
            onPressed: () => SystemNavigator.pop(),
          ),
        ],
      ),
      body: _isLinked ? _buildDashboard() : _buildPairing(),
    );
  }

  Widget _buildPairing() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: _codeController,
            maxLength: 4,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(labelText: "Enter Projector Code"),
            onChanged: (val) async {
              if (val.length == 4) {
                bool ok = await _service.linkRemoteToDisplay(val, "Classroom 101");
                setState(() => _isLinked = ok);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return Column(
      children: [
        const SizedBox(height: 20),
        // NEW: QR Security Rotation Slider
        const Text("QR Security Rotation (Seconds)", style: TextStyle(fontWeight: FontWeight.bold)),
        Slider(
          value: _rotationSeconds.toDouble(),
          min: 5,
          max: 30,
          divisions: 5,
          label: "$_rotationSeconds",
          onChanged: _isBroadcasting
              ? null
              : (v) => setState(() => _rotationSeconds = v.toInt()),
        ),
        Text("Current Interval: $_rotationSeconds seconds"),
        const SizedBox(height: 10),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _isBroadcasting ? Colors.red : Colors.green,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            if (_isBroadcasting) {
              _service.stopBroadcasting(_codeController.text);
            } else {
              // Passes the custom rotation time to the service
              _service.startBroadcasting(_codeController.text, seconds: _rotationSeconds);
            }
            setState(() => _isBroadcasting = !_isBroadcasting);
          },
          child: Text(_isBroadcasting ? "STOP ATTENDANCE" : "START ATTENDANCE"),
        ),
        const Divider(height: 40),
        const Text("Students in Classroom:", style: TextStyle(fontWeight: FontWeight.bold)),
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
              return ListView(
                children: snapshot.data!.docs.map((doc) => ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(doc['studentName']),
                  trailing: const Text("Present", style: TextStyle(color: Colors.green)),
                )).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}