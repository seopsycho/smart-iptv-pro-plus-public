package com.smartiptv.pro

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import com.google.android.gms.cast.framework.CastButtonFactory
import androidx.mediarouter.app.MediaRouteButton
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class ChromecastButtonViewFactory(private val messenger: BinaryMessenger) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, id: Int, args: Any?): PlatformView {
        return ChromecastButtonPlatformView(context)
    }
}

class ChromecastButtonPlatformView(context: Context) : PlatformView {
    private val container: FrameLayout = FrameLayout(context)
    private val button: MediaRouteButton = MediaRouteButton(context)

    init {
        try {
            CastButtonFactory.setUpMediaRouteButton(context, button)
        } catch (_: Throwable) {}
        container.addView(button, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))
    }

    override fun getView(): View = container

    override fun dispose() {}
}

