import 'package:flutter/material.dart';
import 'package:smart_iptv_pro/backend/settings_service.dart';

class WhatsNewModal extends StatelessWidget {
  final String version;
  const WhatsNewModal({super.key, required this.version});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("com.smartiptv.pro.RunnerTests: update $version"),
      actions: [
        TextButton(
          onPressed: () async {
            await SettingsService.updateLastSeenVersion();
            Navigator.pop(context, true);
          },
          child: const Text("Don't show again"),
        )
      ],
      content: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          child: const Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: Text(
              '''
Thanks for supporting SmartIPTV PRO+!

We’re committed to giving you the best possible experience.

Here’s what’s new:
- iPad-optimized interface
- Hide unwanted channels instantly
- 90% faster performance
- Added category sorting & hiding features
- Added Watchlists
- Integrated TMDB for personalized recommendations
- Added Chromecast support
- Added AirPlay support
Coming soon:
- Trakt integration
- Live scores for sports and sport programs
''',
            ),
          ),
        ),
      ),
    );
  }
}
