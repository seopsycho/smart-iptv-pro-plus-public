import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AirPlayButton extends StatelessWidget {
  const AirPlayButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!(defaultTargetPlatform == TargetPlatform.iOS && Platform.isIOS)) {
      return const SizedBox.shrink();
    }
    if (kDebugMode) {
      return SizedBox(
        width: 44,
        height: 44,
        child: const Center(
          child: Icon(Icons.airplay),
        ),
      );
    }
    return SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: UiKitView(
            viewType: 'AirPlayRoutePickerView',
            creationParams: null,
            creationParamsCodec: const StandardMessageCodec(),
          ),
        ),
      ),
    );
  }
}
