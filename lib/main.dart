import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/game_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientations: landscape primary + portrait fallback
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
  ]);

  // Full immersive mode — hide status bar and home indicator
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const BxcApp());
}

class BxcApp extends StatelessWidget {
  const BxcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Better xCloud',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF107C10),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
        // Ensure consistent dark styling system-wide
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A1A),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? const Color(0xFF107C10)
                  : Colors.white38),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: const Color(0xFF107C10),
          thumbColor: const Color(0xFF107C10),
          overlayColor: const Color(0xFF107C10).withOpacity(0.12),
        ),
      ),
      home: const GameScreen(),
    );
  }
}
