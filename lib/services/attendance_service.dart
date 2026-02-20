import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Timer? _rotationTimer;

  // 1. Initialize the Web Screen (The Projector)
  Future<String> initWebDisplay() async {
    String code = (1000 + (9999 - 1000) * (DateTime.now().millisecond / 1000)).toInt().toString();

    await _db.collection('sessions').doc(code).set({
      'displayCode': code,
      'status': 'waiting',
      'sessionId': null,
      'currentToken': '',
      'lastHeartbeat': FieldValue.serverTimestamp(),
    });

    return code;
  }

  // 2. Listen to the Screen Data
  Stream<DocumentSnapshot> listenToDisplay(String displayCode) {
    return _db.collection('active_displays').doc(displayCode).snapshots();
  }

  // 3. Pair Phone to Screen
  Future<bool> linkRemoteToDisplay(String code, String className) async {
    try {
      // We check if the document actually exists before trying to update it
      var doc = await _db.collection('sessions').doc(code).get();

      if (doc.exists) {
        await _db.collection('sessions').doc(code).update({
          'status': 'linked',
          'className': className,
          'teacherId': _auth.currentUser?.uid,
        });
        return true;
      }
      return false; // Document wasn't found
    } catch (e) {
      return false;
    }
  }

  // 4. Start Broadcasting (The Rotating Token)
  void startBroadcasting(String displayCode, {int seconds = 7}) {
    _rotationTimer?.cancel();

    _rotationTimer = Timer.periodic(Duration(seconds: seconds), (timer) async {
      String newToken = (100000 + Random().nextInt(900000)).toString();

      await _db.collection('active_displays').doc(displayCode).update({
        'status': 'active',
        'currentToken': newToken,
        'lastHeartbeat': FieldValue.serverTimestamp(),
      });
    });
  }

  // 5. Stop Broadcasting
  void stopBroadcasting(String code) async {
    try {
      await _db.collection('sessions').doc(code).update({
        'status': 'stopped',
        'currentToken': '', // Clear the token so scans stop working
      });
    } catch (e) {
      print("Error stopping session: $e");
    }
  }
  Future<bool> submitAttendance(String token, String studentName) async {
    // 1. Search for a session that is 'active' and matches this token
    var snapshot = await _db.collection('sessions')
        .where('currentToken', isEqualTo: token)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return false; // The token is old or doesn't exist
    }

    // 2. Add the student to the 'attendance' list for that session
    String sessionId = snapshot.docs.first.id;
    await _db.collection('sessions').doc(sessionId).collection('attendance').add({
      'studentName': studentName,
      'timestamp': FieldValue.serverTimestamp(),
    });

    return true;
  }
}