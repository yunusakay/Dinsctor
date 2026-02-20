import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Add this import

class AttendanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // Added this declaration
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
          'teacherId': _auth.currentUser?.uid, // Fixed: Uses current user ID
        });
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void startBroadcasting(String displayCode) {
    _rotationTimer?.cancel();
    _rotationTimer = Timer.periodic(const Duration(seconds: 7), (timer) async {
      String newToken = (100000 + Random().nextInt(900000)).toString();
      // FIXED: Uses 'sessions' collection instead of 'active_displays'
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