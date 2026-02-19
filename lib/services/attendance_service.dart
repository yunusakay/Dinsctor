import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Timer? _rotationTimer;

  // 1. Initialize the Web Screen (The Projector)
  Future<String> initWebDisplay() async {
    String displayCode = (1000 + Random().nextInt(9000)).toString();

    await _db.collection('active_displays').doc(displayCode).set({
      'displayCode': displayCode,
      'status': 'waiting',
      'sessionId': null,
      'currentToken': '',
      'lastHeartbeat': FieldValue.serverTimestamp(),
    });

    return displayCode;
  }

  // 2. Listen to the Screen Data
  Stream<DocumentSnapshot> listenToDisplay(String displayCode) {
    return _db.collection('active_displays').doc(displayCode).snapshots();
  }

  // 3. Pair Phone to Screen
  Future<bool> linkRemoteToDisplay(String displayCode, String classId) async {
    DocumentSnapshot doc = await _db.collection('active_displays').doc(displayCode).get();

    if (!doc.exists) return false;

    String sessionId = _db.collection('sessions').doc().id;
    await _db.collection('sessions').doc(sessionId).set({
      'sessionId': sessionId,
      'classId': classId,
      'createdAt': FieldValue.serverTimestamp(),
      'attendees': [],
    });

    await _db.collection('active_displays').doc(displayCode).update({
      'status': 'linked',
      'sessionId': sessionId,
    });

    return true;
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
  void stopBroadcasting(String displayCode) {
    _rotationTimer?.cancel();
    _db.collection('active_displays').doc(displayCode).update({
      'status': 'stopped',
      'currentToken': '',
    });
  }
}