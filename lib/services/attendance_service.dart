import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    await _db.collection('sessions').doc(code).update({
      'status': 'stopped',
      'currentToken': '', // Wipes the QR code
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
      'studentId': _auth.currentUser?.uid, // FIXED: Saves ID so they can leave later!
      'timestamp': FieldValue.serverTimestamp(),
    });
    return true;
  }

  // NEW: Teacher kicks student using Document ID
  Future<void> kickStudent(String sessionId, String attendanceDocId) async {
    await _db.collection('sessions').doc(sessionId).collection('attendance').doc(attendanceDocId).delete();
  }

  // NEW: Student leaves by searching for their ID
  Future<void> leaveClassroom(String sessionId) async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return;

    var snapshot = await _db.collection('sessions').doc(sessionId).collection('attendance').where('studentId', isEqualTo: uid).get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete(); // Removes them from list
    }
  }
}