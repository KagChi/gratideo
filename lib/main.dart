import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app.dart';
import 'data/content.dart';
import 'data/settings.dart';
import 'services/purchases.dart';
import 'services/reminders.dart';
import 'services/soundscape.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.isaacmunandar.gratideo.audio',
    androidNotificationChannelName: 'Gratideo soundscape',
    androidNotificationOngoing: true,
  );
  final settings = await Settings.load();
  await Content.instance.load();
  await Soundscape.instance.init(modeId: settings.sound, volume: settings.volume);
  await Reminders.instance.init();
  // Not awaited: the store can be slow and must never block first paint.
  Purchases.instance.init(settings);
  Reminders.instance.schedule(settings);
  runApp(GratideoApp(settings: settings));
}
