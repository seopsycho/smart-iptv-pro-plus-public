package com.smartiptv.pro

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        // Register PlatformView for Chromecast button
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "ChromecastButtonView",
            ChromecastButtonViewFactory(messenger)
        )
        // Register Chromecast method channel
        ChromecastChannel.register(this, messenger)
    }
}
