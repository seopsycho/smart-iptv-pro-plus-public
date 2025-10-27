import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' as dotenv;
import 'package:open_tv/backend/settings_service.dart';
import 'package:open_tv/backend/sql.dart';
import 'package:open_tv/home.dart';
import 'package:open_tv/models/filters.dart';
import 'package:open_tv/models/home_manager.dart';
import 'package:open_tv/models/settings.dart';
import 'package:open_tv/setup.dart';
import 'package:open_tv/onboarding.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.dotenv.load(fileName: ".env");
  } catch (_) {}
  final hasSources = await Sql.hasSources();
  final settings = await SettingsService.getSettings();
  final hasSeenOnboarding = await SettingsService.getHasSeenOnboarding();
  runApp(MyApp(
    skipSetup: hasSources,
    settings: settings,
    showOnboarding: !hasSeenOnboarding,
  ));
}

class MyApp extends StatelessWidget {
  final bool skipSetup;
  final Settings settings;
  final bool showOnboarding;
  const MyApp({super.key, required this.skipSetup, required this.settings, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Fred TV',
        theme: ThemeData(
          useMaterial3: true, // Enables Material You
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        home: showOnboarding
            ? Onboarding(skipSetup: skipSetup, settings: settings)
            : (skipSetup
            ? Home(
                firstLaunch: true,
                refresh: settings.refreshOnStart,
                home: HomeManager(
                    filters: Filters(
                  viewType: settings.defaultView,
                )))
            : const Setup()));
  }
}
