import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'audio/player_service.dart';
import 'core/wave_scope.dart';
import 'core/wave_theme.dart';
import 'data/music_api.dart';
import 'ui/root_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Warms the liquid-glass shader pipeline so the first frame is not the one
  // that pays for compilation.
  await LiquidGlassWidgets.initialize();
  await PlayerService.configureSession();

  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

  // Demo builds keep the semantics tree on so the screenshot tooling in
  // tool/capture_screenshots.mjs can address widgets by label instead of by
  // pixel coordinates.
  if (kDemoMode) SemanticsBinding.instance.ensureSemantics();

  runApp(
    LiquidGlassWidgets.wrap(
      // Without this the package cannot see that the app is in dark mode, and
      // its own docs warn that glass borders and shadows then drop out — which
      // is what made the chrome read as flat grey instead of glass.
      brightnessResolver: CupertinoTheme.maybeBrightnessOf,
      theme: GlassThemeData.simple(
        blur: 12,
        thickness: 24,
        saturation: 1.6,
        brightness: Brightness.dark,
      ),
      child: const WaveApp(),
    ),
  );
}

class WaveApp extends StatefulWidget {
  const WaveApp({super.key});

  @override
  State<WaveApp> createState() => _WaveAppState();
}

class _WaveAppState extends State<WaveApp> {
  final WaveServices _services = WaveServices();

  @override
  void initState() {
    super.initState();
    _services.favorites.load();
  }

  @override
  void dispose() {
    _services.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WaveScope(
      services: _services,
      child: const CupertinoApp(
        title: 'Wave',
        debugShowCheckedModeBanner: false,
        theme: CupertinoThemeData(
          brightness: Brightness.dark,
          primaryColor: WaveColors.violet,
          scaffoldBackgroundColor: WaveColors.abyss,
          textTheme: CupertinoTextThemeData(
            primaryColor: WaveColors.textPrimary,
            textStyle: WaveText.body,
            navTitleTextStyle: WaveText.section,
            navLargeTitleTextStyle: WaveText.largeTitle,
          ),
        ),
        home: RootShell(),
      ),
    );
  }
}
