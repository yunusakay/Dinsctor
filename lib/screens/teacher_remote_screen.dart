import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Needed for Sign Out
import 'package:students_checker/services/attendance_service.dart';

class TeacherRemoteScreen extends StatefulWidget {
  @override
  _TeacherRemoteScreenState createState() => _TeacherRemoteScreenState();
}

class _TeacherRemoteScreenState extends State<TeacherRemoteScreen> {
  final AttendanceService _service = AttendanceService();
  final TextEditingController _codeController = TextEditingController();

  bool _isLinked = false;
  bool _isBroadcasting = false; // Track if the timer is running

  // Exit/Logout Function
  void _handleExit() async {
    if (_isBroadcasting) {
      // Use _codeController.text here too
      _service.stopBroadcasting(_codeController.text);
    }

    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _link(String value) async {
    if (value.length == 4) {
      setState(() => _isLoading = true); // Add a loading spinner for better UX
      bool success = await _service.linkRemoteToDisplay(value, "Math 101");

      if (mounted) {
        if (success) {
          setState(() {
            _isLinked = true;
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Code not found. Is the Web screen open?")),
          );
        }
      }
    }
  }

  void _toggleAttendance() {
    // Use _codeController.text instead of displayCode
    if (_isBroadcasting) {
      _service.stopBroadcasting(_codeController.text);
    } else {
      _service.startBroadcasting(_codeController.text);
    }
    setState(() => _isBroadcasting = !_isBroadcasting);
  }

  @override
  Widget _buildPairingUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Enter Projector Code", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 30),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 4, // Restrict to 4 digits
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 40, letterSpacing: 20, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            counterText: "", // Hides the 0/4 counter
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          ),
          onChanged: _link, // TRIGGERS AUTOMATICALLY ON TYPING
        ),
        if (_isLoading) ...[
          const SizedBox(height: 20),
          const CircularProgressIndicator(),
        ]
      ],
    );
  }

  // Control UI (After connection)
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
          Text(
            _isBroadcasting ? "Attendance is LIVE" : "Ready to Start",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isBroadcasting ? Colors.redAccent : Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: _toggleAttendance,
              child: Text(
                _isBroadcasting ? "STOP ATTENDANCE" : "START ATTENDANCE",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}