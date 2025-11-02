import 'package:flutter/material.dart';
import 'package:smart_iptv_pro/backend/settings_service.dart';
import 'package:smart_iptv_pro/home.dart';
import 'package:smart_iptv_pro/models/filters.dart';
import 'package:smart_iptv_pro/models/home_manager.dart';
import 'package:smart_iptv_pro/models/settings.dart';
import 'package:smart_iptv_pro/setup.dart';

class Onboarding extends StatefulWidget {
  final bool skipSetup;
  final Settings settings;
  const Onboarding(
      {super.key, required this.skipSetup, required this.settings});

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final PageController _controller = PageController();
  int _index = 0;

  void _finish() async {
    await SettingsService.setHasSeenOnboarding();
    if (widget.skipSetup) {
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (context) => Home(
                    firstLaunch: true,
                    refresh: widget.settings.isRefreshDueNow(),
                    home: HomeManager(
                        filters:
                            Filters(viewType: widget.settings.defaultView)),
                  )),
          (route) => false);
    } else {
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const Setup()),
          (route) => false);
    }
  }

  Widget _slide(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 100),
          const SizedBox(height: 24),
          Text(title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(subtitle,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [TextButton(onPressed: _finish, child: const Text("Skip"))],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  _slide(Icons.info, "Legal Disclaimer",
                      "SmartIPTV Pro+ does not provide or host any content. You must supply your own playlists or Xtream credentials. You are solely responsible for the content you access and stream."),
                  _slide(Icons.movie, "Movies and Series",
                      "Bring your library with films, series, and episodes."),
                  _slide(Icons.play_circle_fill, "Easy Playback",
                      "Fast player with AirPlay and Chromecast. Resume where you left off."),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  3,
                  (i) => Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 16),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _index == i
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant),
                      )),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    onPressed: () {
                      if (_index < 2) {
                        _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut);
                      } else {
                        _finish();
                      }
                    },
                    child: Text(_index < 2 ? "Next" : "Get Started")),
              ),
            )
          ],
        ),
      ),
    );
  }
}
