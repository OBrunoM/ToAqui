import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FcmService {
  FcmService(this._firestore, [FirebaseMessaging? messaging])
      : _messaging = messaging;

  final FirebaseFirestore _firestore;
  final FirebaseMessaging? _messaging;

  Future<void> saveToken({required String uid, required String token}) {
    return _firestore.collection('users').doc(uid).set(
      {'fcmToken': token},
      SetOptions(merge: true),
    );
  }

  Future<void> registerToken(String uid) async {
    final messaging = _messaging ?? FirebaseMessaging.instance;

    await messaging.requestPermission();

    final token = await messaging.getToken();
    if (token != null) {
      await saveToken(uid: uid, token: token);
    }

    messaging.onTokenRefresh.listen((newToken) {
      saveToken(uid: uid, token: newToken);
    });
  }
}
