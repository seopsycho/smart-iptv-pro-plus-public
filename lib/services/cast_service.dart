import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:smart_iptv_pro/models/channel.dart';
import 'package:smart_iptv_pro/models/media_type.dart';

class CastService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      const appId = GoogleCastDiscoveryCriteria.kDefaultApplicationId;
      GoogleCastOptions? options;
      if (Platform.isIOS) {
        options = IOSGoogleCastOptions(
          GoogleCastDiscoveryCriteriaInitialize.initWithApplicationID(appId),
        );
      } else if (Platform.isAndroid) {
        options = GoogleCastOptionsAndroid(appId: appId);
      }
      if (options != null) {
        GoogleCastContext.instance.setSharedInstanceWithOptions(options);
        GoogleCastDiscoveryManager.instance.startDiscovery();
      }
      _initialized = true;
    } catch (_) {
      // best-effort init, ignore errors here
    }
  }

  static Future<void> ensureConnected(BuildContext context) async {
    // Always show the device picker; user can confirm or dismiss if already connected
    await showDevicePicker(context);
  }

  static Future<void> showDevicePicker(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cast),
                    const SizedBox(width: 8),
                    Text('Cast devices', style: Theme.of(ctx).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 8),
                StreamBuilder<List<GoogleCastDevice>>(
                  stream: GoogleCastDiscoveryManager.instance.devicesStream,
                  builder: (context, snapshot) {
                    final devices = snapshot.data ?? const <GoogleCastDevice>[];
                    if (devices.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Text('No Cast devices found'),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: devices.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final d = devices[index];
                        return ListTile(
                          leading: const Icon(Icons.cast),
                          title: Text(d.friendlyName),
                          subtitle: Text(d.modelName ?? 'Chromecast'),
                          onTap: () async {
                            try {
                              await GoogleCastSessionManager.instance
                                  .startSessionWithDevice(d);
                              // Close the sheet after connect
                              if (context.mounted) Navigator.of(context).pop();
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to connect: $e')),
                                );
                              }
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> castChannel(Channel channel) async {
    final url = channel.url?.trim();
    if (url == null || url.isEmpty) {
      return;
    }
    final contentType = _contentTypeForUrl(url);
    // Choose stream type conservatively; many IPTV streams are live (HLS)
    final streamType = channel.mediaType == MediaType.livestream
        ? CastMediaStreamType.live
        : CastMediaStreamType.buffered;

    final mediaInfo = GoogleCastMediaInformation(
      contentId: channel.streamId?.toString() ?? channel.name,
      streamType: streamType,
      contentUrl: Uri.parse(url),
      contentType: contentType,
      // Note: Some IPTV streams require HTTP headers like Referer/User-Agent.
      // The default Chromecast receiver cannot use custom headers; such streams
      // may fail to load when casting.
    );

    await GoogleCastRemoteMediaClient.instance.loadMedia(
      mediaInfo,
      autoPlay: true,
      playPosition: Duration.zero,
      playbackRate: 1.0,
    );
  }

  static String _contentTypeForUrl(String url) {
    final u = url.toLowerCase();
    if (u.contains('.m3u8')) return 'application/x-mpegURL';
    if (u.endsWith('.mpd')) return 'application/dash+xml';
    if (u.endsWith('.mp4')) return 'video/mp4';
    if (u.endsWith('.webm')) return 'video/webm';
    if (u.endsWith('.mov')) return 'video/quicktime';
    return 'application/x-mpegURL';
  }
}
