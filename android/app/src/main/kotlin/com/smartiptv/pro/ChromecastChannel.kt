package com.smartiptv.pro

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.BinaryMessenger
import com.google.android.gms.cast.MediaMetadata
import com.google.android.gms.cast.MediaInfo
import com.google.android.gms.cast.MediaLoadRequestData
import com.google.android.gms.cast.framework.CastContext
import com.google.android.gms.cast.framework.media.RemoteMediaClient

class ChromecastChannel private constructor(private val context: Context, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "com.smartiptv.pro/chromecast")

    init {
        channel.setMethodCallHandler(this)
    }

    companion object {
        fun register(context: Context, messenger: BinaryMessenger): ChromecastChannel {
            return ChromecastChannel(context, messenger)
        }
    }

    private fun client(): RemoteMediaClient? {
        val session = CastContext.getSharedInstance(context).sessionManager.currentCastSession
        return session?.remoteMediaClient
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "load" -> {
                val url = call.argument<String>("url")
                val contentType = call.argument<String>("contentType") ?: "video/mp4"
                val title = call.argument<String>("title") ?: ""
                val subtitle = call.argument<String>("subtitle")
                val imageUrl = call.argument<String>("imageUrl")
                val startSeconds = call.argument<Double>("startSeconds") ?: 0.0
                val streamType = call.argument<String>("streamType") ?: "buffered"

                val c = client() ?: run {
                    result.error("no_session", "No active Cast session", null)
                    return
                }

                val metadata = MediaMetadata(MediaMetadata.MEDIA_TYPE_MOVIE).apply {
                    putString(MediaMetadata.KEY_TITLE, title)
                    subtitle?.let { putString(MediaMetadata.KEY_SUBTITLE, it) }
                    imageUrl?.let { addImage(com.google.android.gms.common.images.WebImage(android.net.Uri.parse(it))) }
                }

                val info = MediaInfo.Builder(url!!)
                    .setContentType(contentType)
                    .setStreamType(if (streamType == "live") MediaInfo.STREAM_TYPE_LIVE else MediaInfo.STREAM_TYPE_BUFFERED)
                    .setMetadata(metadata)
                    .build()

                val req = MediaLoadRequestData.Builder()
                    .setMediaInfo(info)
                    .setAutoplay(true)
                    .setCurrentTime((startSeconds * 1000L).toLong())
                    .build()

                c.load(req)
                result.success(true)
            }
            "play" -> { client()?.play(); result.success(true) }
            "pause" -> { client()?.pause(); result.success(true) }
            "seek" -> {
                val pos = call.argument<Double>("positionSeconds") ?: 0.0
                client()?.seek((pos * 1000L).toLong())
                result.success(true)
            }
            "stop" -> { client()?.stop(); result.success(true) }
            "getStatus" -> {
                val status = client()?.mediaStatus
                if (status == null) {
                    result.success(null)
                } else {
                    val map = hashMapOf<String, Any?>(
                        "duration" to status.mediaInfo?.streamDuration,
                        "position" to status.streamPosition,
                        "playerState" to status.playerState
                    )
                    result.success(map)
                }
            }
            else -> result.notImplemented()
        }
    }
}
