import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'agent_forge.dart';
import 'depot.dart';

// ============================================================
// BEACON HUB — FCM + local notification presenter
// ============================================================
// Handles:
//   • asking the OS for the push permission (Android 13+ dialog),
//   • rendering foreground messages via a local notification (so users
//     see them without an active tray notification),
//   • dispatching taps into three lanes:
//        cold  → save the link, opened after next FlowRouter boot
//        warm  → live-load the link over the active WebStage
//        fg    → local notif tap fires the same warm handler
// ============================================================

// Channel id must match the AndroidManifest meta-data
// `com.google.firebase.messaging.default_notification_channel_id`.
// Rename atomically per project — see `.cursor/rules/custom_screens.md`.
const String jesterChannelId = 'jester_pulse';
const String jesterChannelLabel = 'Jester Pulse';
// Drawable resource name only — flutter_local_notifications does NOT
// accept the '@drawable/' XML prefix here.
const String _iconRef = 'ic_notification';

@pragma('vm:entry-point')
Future<void> _backgroundBridge(RemoteMessage message) async {
  // The OS renders background pushes; taps arrive on resume or cold-
  // boot, so nothing to do inside this isolate.
}

class BeaconHub {
  BeaconHub(this._depot);

  final Depot _depot;
  final FlutterLocalNotificationsPlugin _tray =
      FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _fm;
  String? _cachedToken;
  bool _wiredUp = false;

  /// Live (warm / foreground) push link — the shell hot-loads it into
  /// the currently open WebView.
  void Function(String link)? onLinkReady;

  /// Notifies when FCM rotates the token so the shell can re-post the
  /// gateway request with the fresh token.
  void Function(String token)? onTokenRotated;

  String? get token => _cachedToken;

  Future<void> prime() async {
    if (_wiredUp) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _fm = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(_backgroundBridge);

      await _wireLocal();

      _cachedToken = await _fm!.getToken();
      _fm!.onTokenRefresh.listen((String t) {
        _cachedToken = t;
        onTokenRotated?.call(t);
      });

      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_onWarmTap);

      final RemoteMessage? initial = await _fm!.getInitialMessage();
      if (initial != null) _onColdTap(initial);

      _wiredUp = true;
    } catch (_) {
      // Firebase not configured yet — push stays dormant; app keeps
      // running through the offline / native path.
    }
  }

  Future<void> _wireLocal() async {
    const AndroidInitializationSettings android =
        AndroidInitializationSettings(_iconRef);
    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const InitializationSettings init = InitializationSettings(
      android: android,
      iOS: ios,
    );

    await _tray.initialize(
      init,
      onDidReceiveNotificationResponse: (NotificationResponse resp) {
        final String? payload = resp.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final Map<String, dynamic> data =
              jsonDecode(payload) as Map<String, dynamic>;
          final String? link = data['url'] as String?;
          if (link != null && link.isNotEmpty) onLinkReady?.call(link);
        } catch (_) {}
      },
    );

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? android = _tray
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          jesterChannelId,
          jesterChannelLabel,
          description: 'Bonuses, updates and offers',
          importance: Importance.high,
        ),
      );
    }
  }

  /// Asks for the runtime notification permission (Android 13+ dialog).
  /// Also records the OS-denied flag so the invite screen never loops.
  Future<bool> askForPermission() async {
    if (_fm == null) return false;
    final NotificationSettings settings = await _fm!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final AuthorizationStatus status = settings.authorizationStatus;
    final bool granted = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
    await _depot.setBeaconGranted(granted);
    if (status == AuthorizationStatus.denied) {
      await _depot.markBeaconOsBlocked();
    }
    return granted;
  }

  Future<void> _onForeground(RemoteMessage message) async {
    final RemoteNotification? n = message.notification;
    if (n == null || !Platform.isAndroid) return;

    AndroidNotificationDetails? details;
    final String? imageUrl = n.android?.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final Uint8List? bytes = await _grabImage(imageUrl);
      if (bytes != null) {
        details = AndroidNotificationDetails(
          jesterChannelId,
          jesterChannelLabel,
          importance: Importance.high,
          priority: Priority.high,
          icon: _iconRef,
          styleInformation: BigPictureStyleInformation(
            ByteArrayAndroidBitmap(bytes),
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        );
      }
    }

    details ??= const AndroidNotificationDetails(
      jesterChannelId,
      jesterChannelLabel,
      importance: Importance.high,
      priority: Priority.high,
      icon: _iconRef,
    );

    await _tray.show(
      n.hashCode,
      n.title,
      n.body,
      NotificationDetails(android: details),
      payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
    );
  }

  void _onColdTap(RemoteMessage message) {
    final String? link = message.data['url'] as String?;
    if (link != null && link.isNotEmpty) {
      _depot.stashPendingLink(link);
    }
  }

  void _onWarmTap(RemoteMessage message) {
    final String? link = message.data['url'] as String?;
    if (link != null && link.isNotEmpty) {
      onLinkReady?.call(link);
    }
  }

  Future<Uint8List?> _grabImage(String url) async {
    try {
      final response = await jesterNet
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (_) {}
    return null;
  }
}
