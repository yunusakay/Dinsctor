import 'package:flutter/material.dart';
import 'package:students_checker/services/attendance_service.dart';

class TeacherRemoteScreen extends StatefulWidget {
  @override
  _TeacherRemoteScreenState createState() => _TeacherRemoteScreenState();
}

class _TeacherRemoteScreenState extends State<TeacherRemoteScreen> {
  final AttendanceService _service = AttendanceService();
  final TextEditingController _codeController = TextEditingController();
  bool _isLinked = false;

  void _link() async {
    bool success = await _service.linkRemoteToDisplay(_codeController.text, "Math 101");
    if (success) setState(() => _isLinked = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Teacher Remote")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: _isLinked
            ? Center(child: ElevatedButton(onPressed: () => _service.startBroadcasting(_codeController.text), child: Text("START ATTENDANCE")))
            : Column(children: [
          TextField(controller: _codeController, decoration: InputDecoration(labelText: "Enter Screen Code")),
          ElevatedButton(onPressed: _link, child: Text("CONNECT")),
        ]),
      ),
    );
  }
}