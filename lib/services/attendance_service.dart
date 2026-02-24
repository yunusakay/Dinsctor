import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AttendanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Timer? _rotationTimer;

  Future<String> initWebDisplay() async {
    // Generates a true random 4-digit code
    String code = (Random().nextInt(9000) + 1000).toString();
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

  void startBroadcasting(String displayCode, {int seconds = 7, bool autoStop = false, Function? onAutoStop}) {
    _rotationTimer?.cancel();

    if (autoStop) {
      String newToken = (100000 + Random().nextInt(900000)).toString();
      _db.collection('sessions').doc(displayCode).update({
        'status': 'active',
        'currentToken': newToken,
        'previousToken': '',
        'lastHeartbeat': FieldValue.serverTimestamp(),
      });

      _rotationTimer = Timer(Duration(seconds: seconds), () {
        stopBroadcasting(displayCode);
        if (onAutoStop != null) onAutoStop();
      });
    } else {
      void rotateToken() async {
        String newToken = (100000 + Random().nextInt(900000)).toString();
        var doc = await _db.collection('sessions').doc(displayCode).get();
        String prevToken = doc.exists ? (doc.data()?['currentToken'] ?? '') : '';

        await _db.collection('sessions').doc(displayCode).update({
          'status': 'active',
          'currentToken': newToken,
          'previousToken': prevToken,
          'lastHeartbeat': FieldValue.serverTimestamp(),
        });
      }

      rotateToken();
      _rotationTimer = Timer.periodic(Duration(seconds: seconds), (timer) {
        rotateToken();
      });
    }
  }

  void stopBroadcasting(String code) async {
    _rotationTimer?.cancel();
    await _db.collection('sessions').doc(code).update({
      'status': 'stopped',
      'currentToken': '',
    });
  }

  Future<void> finishSession(String code) async {
    _rotationTimer?.cancel();
    await _db.collection('sessions').doc(code).update({
      'status': 'finished',
      'currentToken': '',
    });
  }

  Future<bool> submitAttendance(String token, String studentName) async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    var currentSnap = await _db.collection('sessions')
        .where('currentToken', isEqualTo: token)
        .where('status', isEqualTo: 'active')
        .limit(1).get();

    var previousSnap = await _db.collection('sessions')
        .where('previousToken', isEqualTo: token)
        .where('status', isEqualTo: 'active')
        .limit(1).get();

    if (currentSnap.docs.isEmpty && previousSnap.docs.isEmpty) return false;

    String sessionId = currentSnap.docs.isNotEmpty ? currentSnap.docs.first.id : previousSnap.docs.first.id;

    var duplicateCheck = await _db.collection('sessions').doc(sessionId).collection('attendance')
        .where('studentId', isEqualTo: uid).get();

    if (duplicateCheck.docs.isNotEmpty) return true;

    await _db.collection('sessions').doc(sessionId).collection('attendance').add({
      'studentName': studentName,
      'studentEmail': _auth.currentUser?.email,
      'studentId': uid,
      'timestamp': FieldValue.serverTimestamp(),
    });
    return true;
  }

  // --- MISSING METHODS RESTORED ---
  Future<void> kickStudent(String sessionId, String attendanceDocId) async {
    await _db.collection('sessions').doc(sessionId).collection('attendance').doc(attendanceDocId).delete();
  }

  Future<void> leaveClassroom(String sessionId) async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return;

    var snapshot = await _db.collection('sessions').doc(sessionId).collection('attendance').where('studentId', isEqualTo: uid).get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}