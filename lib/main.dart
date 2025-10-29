import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' as dotenv;
import 'package:smart_iptv_pro/backend/settings_service.dart';
import 'package:smart_iptv_pro/backend/sql.dart';
import 'package:smart_iptv_pro/home.dart';
import 'package:smart_iptv_pro/models/filters.dart';
import 'package:smart_iptv_pro/models/home_manager.dart';
import 'package:smart_iptv_pro/models/settings.dart';
import 'package:smart_iptv_pro/setup.dart';
import 'package:smart_iptv_pro/onboarding.dart';
import 'package:smart_iptv_pro/services/cast_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.dotenv.load(fileName: ".env");
  } catch (_) {}
  await CastService.initialize();
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
  const MyApp(
      {super.key,
      required this.skipSetup,
      required this.settings,
      required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
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
