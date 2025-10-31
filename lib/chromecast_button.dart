import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChromecastButton extends StatefulWidget {
  final double width;
  final double height;
  final Color? tintColor;
  
  const ChromecastButton({
    super.key, 
    this.width = 44.0, 
    this.height = 44.0,
    this.tintColor,
  });

  @override
  State<ChromecastButton> createState() => _ChromecastButtonState();
}

class _ChromecastButtonState extends State<ChromecastButton> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (!(defaultTargetPlatform == TargetPlatform.android ||
        (defaultTargetPlatform == TargetPlatform.iOS && Platform.isIOS))) {
      return const SizedBox.shrink();
    }
    if (kDebugMode && defaultTargetPlatform == TargetPlatform.iOS && Platform.isIOS) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: Center(
          child: Icon(Icons.cast, color: widget.tintColor ?? Theme.of(context).iconTheme.color),
        ),
      );
    }

    final child = SizedBox(
      width: widget.width,
      height: widget.height,
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: defaultTargetPlatform == TargetPlatform.iOS
              ? UiKitView(
                  viewType: 'ChromecastButtonView',
                  creationParams: null,
                  creationParamsCodec: const StandardMessageCodec(),
                )
              : AndroidView(
                  viewType: 'ChromecastButtonView',
                  creationParams: null,
                  creationParamsCodec: const StandardMessageCodec(),
                ),
        ),
      ),
    );

    return IconTheme(
      data: IconThemeData(color: widget.tintColor ?? Theme.of(context).iconTheme.color),
      child: child,
    );
  }
}
