import 'package:flutter/material.dart';
import 'package:funday_download_media_project/audio_provider.dart';
import 'package:funday_download_media_project/page/audio_page.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AudioProvider()..loadAudio(),
      child: MaterialApp(
        home: const AudioPage(),
      ),
    );
  }
}
