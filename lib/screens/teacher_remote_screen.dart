import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/attendance_service.dart';

class TeacherRemoteScreen extends StatefulWidget {
  const TeacherRemoteScreen({super.key});

  @override
  _TeacherRemoteScreenState createState() => _TeacherRemoteScreenState();
}

class _TeacherRemoteScreenState extends State<TeacherRemoteScreen> {
  final AttendanceService _service = AttendanceService();
  final TextEditingController _codeController = TextEditingController();

  bool _isLinked = false;
  bool _isBroadcasting = false;
  bool _isLoading = false;

  void _handleExit() async {
    if (_isBroadcasting) {
      _service.stopBroadcasting(_codeController.text);
    }
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  void _link(String value) async {
    if (value.length == 4) {
      setState(() => _isLoading = true);
      // Attempt to link to the session code
      bool success = await _service.linkRemoteToDisplay(value, "Math 101");

      if (mounted) {
        setState(() {
          _isLinked = success;
          _isLoading = false;
        });
        if (success) {
          FocusScope.of(context).unfocus(); // Close keyboard automatically
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Code not found. Is the Web screen open?")),
          );
        }
      }
    }
  }

  void _toggleAttendance() {
    if (_isBroadcasting) {
      _service.stopBroadcasting(_codeController.text);
    } else {
      _service.startBroadcasting(_codeController.text);
    }
    setState(() => _isBroadcasting = !_isBroadcasting);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Teacher Remote"),
        automaticallyImplyLeading: false, // Removes back button
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _handleExit),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: _isLinked ? _buildControlUI() : _buildPairingUI(),
      ),
    );
  }

  Widget _buildPairingUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Enter Projector Code", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 30),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 40, letterSpacing: 20),
          decoration: const InputDecoration(counterText: "", border: OutlineInputBorder()),
          onChanged: _link, // Auto-connect on 4th digit
        ),
        if (_isLoading) const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildControlUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isBroadcasting ? Icons.sensors : Icons.sensors_off,
            size: 80,
            color: _isBroadcasting ? Colors.green : Colors.grey,
          ),
          const SizedBox(height: 20),
          Text(_isBroadcasting ? "Attendance is LIVE" : "Ready to Start"),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isBroadcasting ? Colors.redAccent : Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: _toggleAttendance,
              child: Text(_isBroadcasting ? "STOP ATTENDANCE" : "START ATTENDANCE"),
            ),
          ),
        ],
      ),
    );
  }
}