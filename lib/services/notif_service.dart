import 'package:firebase_messaging/firebase_messaging.dart';

import '../models/models.dart';
import 'user_repo.dart';

/// Push plumbing. The messages themselves are sent by Cloud Functions; the app
/// only asks permission, subscribes to the right topic and stores the token.
class Notifs {
  Notifs._();

  static const cofounderTopic = 'cofounders';

  static Future<void> register(AppUser user) async {
    try {
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission();

      final token = await fm.getToken();
      if (token != null) await UserRepo.saveFcmToken(user.uid, token);
      fm.onTokenRefresh.listen((t) => UserRepo.saveFcmToken(user.uid, t));

      // Co-founders and the master share one topic for farm-wide alerts.
      if (user.role.isStaff) {
        await fm.subscribeToTopic(cofounderTopic);
      } else {
        await fm.unsubscribeFromTopic(cofounderTopic);
      }
    } catch (_) {
      // Messaging is a nice-to-have; never let it stop sign-in.
    }
  }

  static Future<void> unregister() async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(cofounderTopic);
    } catch (_) {
      // Ignored.
    }
  }
}
