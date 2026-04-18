import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'screens/discovery_screen.dart';
import 'services/prefs_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.portal.portal_app.audio',
    androidNotificationChannelName: 'Portal Audio',
    androidNotificationOngoing: true,
  );

  final prefs = await PrefsService.create();
  runApp(PortalApp(prefs: prefs));
}

class PortalApp extends StatelessWidget {
  final PrefsService prefs;

  const PortalApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: DiscoveryScreen(prefs: prefs),
    );
  }
}
