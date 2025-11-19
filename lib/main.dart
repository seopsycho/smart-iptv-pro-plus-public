import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' as dotenv;
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:smart_iptv_pro/backend/settings_service.dart';
import 'package:smart_iptv_pro/backend/sql.dart';
import 'package:smart_iptv_pro/home.dart';
import 'package:smart_iptv_pro/setup.dart';
import 'package:smart_iptv_pro/onboarding.dart';
import 'package:smart_iptv_pro/services/downloads_service.dart';
import 'package:smart_iptv_pro/image_cache_manager.dart';
import 'package:smart_iptv_pro/models/filters.dart';
import 'package:smart_iptv_pro/models/home_manager.dart';
import 'package:smart_iptv_pro/models/settings.dart';
import 'package:smart_iptv_pro/models/view_type.dart';
import 'package:smart_iptv_pro/settings_view.dart';
import 'package:smart_iptv_pro/services/analytics_service.dart';

Future<void> main() async {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint('FlutterError: \'${details.exceptionAsString()}\'');
      if (details.stack != null) {
        debugPrint(details.stack.toString());
      }
    }
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (kReleaseMode) {
      return const SizedBox.shrink();
    }
    return ErrorWidget(details.exception);
  };

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Firebase.initializeApp();
    } else {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    try {
      await dotenv.dotenv.load(fileName: ".env");
    } catch (_) {}
    await ImageCacheManager.initialize();
    await AnalyticsService.initialize();
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    // Note: logAppOpen will be called when the app successfully starts
    final hasSources = await Sql.hasSources();
    final settings = await SettingsService.getSettings();
    final hasSeenOnboarding = await SettingsService.getHasSeenOnboarding();
    try {
      await DownloadsService.init();
    } catch (_) {}
    runApp(ProviderScope(
      child: MyApp(
        skipSetup: hasSources,
        settings: settings,
        showOnboarding: !hasSeenOnboarding,
      ),
    ));
  }, (Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('Uncaught error: $error');
      debugPrint(stack.toString());
    }
  });
}

class MyApp extends ConsumerWidget {
  final bool skipSetup;
  final Settings settings;
  final bool showOnboarding;
  const MyApp(
      {super.key,
      required this.skipSetup,
      required this.settings,
      required this.showOnboarding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = const ColorScheme.dark().copyWith(
      primary: const Color(0xFFE50914),
      secondary: const Color(0xFFE50914),
      surface: const Color(0xFF16171A),
      background: const Color(0xFF0D0D0F),
      onBackground: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFFFFFFFF),
      error: const Color(0xFFE63946),
      outline: const Color(0xFF2A2A30),
    );

    final baseText = GoogleFonts.interTextTheme(ThemeData.dark().textTheme)
        .apply(bodyColor: Colors.white, displayColor: Colors.white);
    final textTheme = baseText.copyWith(
      titleLarge: GoogleFonts.poppins(
          fontSize: 24, fontWeight: FontWeight.w600, height: 1.3),
      titleMedium: GoogleFonts.poppins(
          fontSize: 20, fontWeight: FontWeight.w600, height: 1.3),
      headlineSmall: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          height: 1.2,
          letterSpacing: -0.5),
      titleSmall: baseText.titleSmall
          ?.copyWith(fontSize: 18, fontWeight: FontWeight.w500, height: 1.3),
      bodyLarge: baseText.bodyLarge?.copyWith(fontSize: 16, height: 1.6),
      bodyMedium: baseText.bodyMedium?.copyWith(fontSize: 16, height: 1.6),
      bodySmall: baseText.bodySmall
          ?.copyWith(fontSize: 12, height: 1.4, color: const Color(0xFFA9A9B2)),
      labelLarge: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.2,
          letterSpacing: 0.5),
    );

    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF0D0D0F),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          height: 1.2,
          letterSpacing: -0.5,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF16171A),
        elevation: 4,
        shadowColor: const Color(0x80000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF2A2A30), width: 1),
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.white, size: 24),
      dividerColor: const Color(0xFF2A2A30),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF16171A),
        hintStyle: const TextStyle(color: Color(0xFF5C5C63)),
        prefixIconColor: const Color(0xFFA9A9B2),
        suffixIconColor: const Color(0xFFA9A9B2),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A2A30), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A2A30), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE50914), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE50914),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          textStyle:
              GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFE50914), width: 1),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          textStyle:
              GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
        ).copyWith(
          overlayColor: const MaterialStatePropertyAll(Color(0x33E50914)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          textStyle:
              GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const Color(0xFFE50914);
          }
          return const Color(0xFF2A2A30);
        }),
        thumbColor: const MaterialStatePropertyAll(Colors.white),
        trackOutlineColor: const MaterialStatePropertyAll(Colors.transparent),
      ),
    );

    return MaterialApp(
      title: 'SmartIPTV Pro+',
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      navigatorObservers:
          AnalyticsService.observer != null ? [AnalyticsService.observer!] : [],
      home: showOnboarding
          ? Onboarding(skipSetup: skipSetup, settings: settings)
          : skipSetup
              ? Home(
                  home: HomeManager(
                    filters: Filters(
                      viewType: settings.defaultView,
                    ),
                  ),
                  refresh: settings.isRefreshDueNow(),
                  firstLaunch: true,
                )
              : Setup(
                  showAppBar: false,
                ),
      routes: {
        '/home': (context) => Home(
              home: HomeManager(
                filters: Filters(
                  viewType: ViewType.all,
                ),
              ),
            ),
        '/settings': (context) => const SettingsView(),
        '/setup': (context) => Setup(showAppBar: true),
      },
    );
  }
}
