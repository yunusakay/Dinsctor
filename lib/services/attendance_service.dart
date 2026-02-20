// lib/services/attendance_service.dart
import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart'; //
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Timer? _rotationTimer;

  Future<String> initWebDisplay() async {
    String code = (1000 + (9999 - 1000) * (DateTime.now().millisecond / 1000)).toInt().toString();
    await _db.collection('sessions').doc(code).set({
      'displayCode': code,
      'status': 'waiting',
      'currentToken': '',
      'lastHeartbeat': FieldValue.serverTimestamp(),
    });
    return code;
  }

  Future<bool> linkRemoteToDisplay(String code, String className) async {
    try {
      var doc = await _db.collection('sessions').doc(code).get();
      if (doc.exists) {
        await _db.collection('sessions').doc(code).update({
          'status': 'linked',
          'className': className,
          'teacherId': _auth.currentUser?.uid,
          'teacherName': _auth.currentUser?.displayName ?? "Teacher",
        });
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void startBroadcasting(String displayCode, {int seconds = 7}) {
    _rotationTimer?.cancel();
    _rotationTimer = Timer.periodic(Duration(seconds: seconds), (timer) async {
      // Generate a new unique token
      String newToken = (100000 + Random().nextInt(900000)).toString();

      await _db.collection('sessions').doc(displayCode).update({
        'status': 'active',
        'currentToken': newToken,
        'lastHeartbeat': FieldValue.serverTimestamp(),
      });
    });
  }

  void stopBroadcasting(String code) async {
    _rotationTimer?.cancel();
    // Security: Wipe the token so old pictures cannot be used
    await _db.collection('sessions').doc(code).update({
      'status': 'stopped',
      'currentToken': '',
    });
  }

  Future<bool> submitAttendance(String token, String studentName) async {
    var snapshot = await _db.collection('sessions')
        .where('currentToken', isEqualTo: token)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return false;

    String sessionId = snapshot.docs.first.id;
    await _db.collection('sessions').doc(sessionId).collection('attendance').add({
      'studentName': studentName,
      'timestamp': FieldValue.serverTimestamp(),
    });
    return true;
  }
}