import 'package:flutter/material.dart';
import 'package:open_tv/backend/settings_service.dart';

class WhatsNewModal extends StatelessWidget {
  final String version;
  const WhatsNewModal({super.key, required this.version});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: Text("What's new: update $version"),
        actions: [
          TextButton(
              onPressed: () async {
                await SettingsService.updateLastSeenVersion();
                Navigator.pop(context, true);
              },
              child: const Text("Don't show again"))
        ],
        content: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
              child: const Padding(
                  padding: EdgeInsets.only(right: 8.0),
                  child: const Text(
                    '''
Hi! Thanks for supporting Fred TV. Here's everything new:

- Changed name from Open TV to Fred TV due to trademark dispute, sorry!

Thanks for using Fred TV! Report issues on the github and share it with your friends.
''',
                  ))),
        ));
  }
}
