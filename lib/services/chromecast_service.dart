import 'dart:async';
import 'package:flutter/services.dart';
import 'package:smart_iptv_pro/models/channel.dart';
import 'package:smart_iptv_pro/models/media_type.dart';

class ChromecastService {
  static const MethodChannel _ch = MethodChannel('com.smartiptv.pro/chromecast');

  static Future<bool> load({
    required String url,
    required String title,
    String? contentType,
    String? subtitle,
    String? imageUrl,
    Duration? startPosition,
    MediaType? mediaType,
    Map<String, String>? headers,
  }) async {
    final streamType = (mediaType == MediaType.livestream) ? 'live' : 'buffered';
    final pos = startPosition?.inSeconds.toDouble() ?? 0.0;
    final ct = contentType ?? _guessContentType(url);
    final args = {
      'url': url,
      'title': title,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
      'startSeconds': pos,
      'contentType': ct,
      'streamType': streamType,
      if (headers != null) 'headers': headers,
    };
    final res = await _ch.invokeMethod('load', args);
    return res == true;
  }

  static Future<void> play() => _ch.invokeMethod('play');
  static Future<void> pause() => _ch.invokeMethod('pause');
  static Future<void> stop() => _ch.invokeMethod('stop');
  static Future<void> seek(Duration position) => _ch.invokeMethod('seek', {
        'positionSeconds': position.inSeconds.toDouble(),
      });

  static String _guessContentType(String url) {
    final u = url.toLowerCase();
    if (u.contains('.m3u8')) return 'application/x-mpegURL';
    if (u.contains('.mpd')) return 'application/dash+xml';
    if (u.contains('.mp4')) return 'video/mp4';
    if (u.contains('.ts')) return 'video/MP2T';
    return 'application/octet-stream';
  }

  static Future<bool> loadChannel(Channel c, {Map<String, String>? headers, Duration? start}) async {
    if (c.url == null || c.url!.isEmpty) return false;
    return load(
      url: c.url!,
      title: c.name,
      contentType: _guessContentType(c.url!),
      imageUrl: c.image,
      startPosition: start,
      mediaType: c.mediaType,
      headers: headers,
    );
  }
}
