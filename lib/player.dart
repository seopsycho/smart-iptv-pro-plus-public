import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:smart_iptv_pro/backend/sql.dart';
import 'package:smart_iptv_pro/models/channel.dart';
import 'package:smart_iptv_pro/models/id_data.dart';
import 'package:smart_iptv_pro/models/media_type.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkvideo;
import 'package:smart_iptv_pro/select_dialog.dart';
import 'package:smart_iptv_pro/services/chromecast_service.dart';
import 'package:smart_iptv_pro/chromecast_button.dart';
import 'package:smart_iptv_pro/airplay_button.dart';
import 'dart:io' show Platform;
import 'package:smart_iptv_pro/airplay_button.dart';
import 'dart:io' show Platform;

class Player extends StatefulWidget {
  final Channel channel;
  const Player({super.key, required this.channel});
  @override
  State<StatefulWidget> createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  late mk.Player player = mk.Player();
  late mkvideo.VideoController videoController =
      mkvideo.VideoController(player);
  late final GlobalKey<VideoState> key = GlobalKey<VideoState>();
  bool exiting = false;
  bool fill = false;
  String? _sourceName;

  Timer? _airPlayTimer;
  bool _airPlayWasConnected = false;
  bool _airPlayStarted = false;

  static const MethodChannel _airPlayCh =
      MethodChannel('com.smartiptv.pro/airplay');

  @override
  void initState() {
    super.initState();
    mk.MediaKit.ensureInitialized();
    initAsync();
    if (Platform.isIOS) {
      _airPlayTimer =
          Timer.periodic(const Duration(milliseconds: 800), (t) async {
        try {
          final connected = await _airPlayCh.invokeMethod('isConnected');
          if (connected == true) {
            if (!_airPlayWasConnected && !_airPlayStarted) {
              final id = widget.channel.id;
              final headers =
                  id != null ? await Sql.getChannelHeaders(id) : null;
              final position = widget.channel.mediaType == MediaType.movie
                  ? player.state.position
                  : Duration.zero;
              final args = {
                'url': widget.channel.url!,
                'startSeconds': position.inSeconds.toDouble(),
                if (headers != null)
                  'headers': {
                    if (headers.referrer != null) 'Referer': headers.referrer!,
                    if (headers.httpOrigin != null)
                      'Origin': headers.httpOrigin!,
                    if (headers.userAgent != null)
                      'User-Agent': headers.userAgent!,
                  },
              };
              final ok = await _airPlayCh.invokeMethod('play', args);
              if (!mounted) return;
              if (ok == true) {
                _airPlayStarted = true;
                await player.pause();
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Playing via AirPlay...')));
              }
            }
            _airPlayWasConnected = true;
          } else {
            _airPlayWasConnected = false;
          }
        } catch (_) {}
      });
    }
  }

  Future<void> initAsync() async {
    final id = widget.channel.id;
    final headers = id != null ? await Sql.getChannelHeaders(id) : null;
    final seconds = (id != null && widget.channel.mediaType == MediaType.movie)
        ? await Sql.getPosition(id)
        : null;
    await player.open(mk.Media(widget.channel.url!,
        start: seconds != null ? Duration(seconds: seconds) : null,
        httpHeaders: headers != null
            ? {
                if (headers.referrer != null) "Referer": headers.referrer!,
                if (headers.httpOrigin != null) "Origin": headers.httpOrigin!,
                if (headers.userAgent != null) "User-Agent": headers.userAgent!,
              }
            : null));
    try {
      final src = await Sql.getSourceFromId(widget.channel.sourceId);
      if (mounted) setState(() => _sourceName = src.name);
    } catch (_) {}
    await key.currentState?.enterFullscreen();
    player.setPlaylistMode(mk.PlaylistMode.single);
  }

  @override
  void dispose() {
    _airPlayTimer?.cancel();
    player.dispose();
    super.dispose();
  }

  Future<void> openSubtitlesModal() async {
    await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => SelectDialog(
            title: "Select subtitles",
            action: (id) async {
              player.setSubtitleTrack(player.state.tracks.subtitle[id]);
              Navigator.of(context).pop();
            },
            data: player.state.tracks.subtitle
                .asMap()
                .entries
                .map((entry) => IdData(
                    id: entry.key,
                    data: entry.value.language != null
                        ? "${entry.value.language} - ${entry.value.id}"
                        : entry.value.id))
                .toList()));
  }

  Future<void> openAudioModal() async {
    await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => SelectDialog(
            title: "Select audio",
            action: (id) async {
              player.setAudioTrack(player.state.tracks.audio[id]);
              Navigator.of(context).pop();
            },
            data: player.state.tracks.audio
                .asMap()
                .entries
                .map((entry) => IdData(
                    id: entry.key,
                    data: entry.value.title ??
                        entry.value.language ??
                        entry.value.id))
                .toList()));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          onExit();
        },
        child: Scaffold(
            backgroundColor: Colors.black,
            body: MaterialVideoControlsTheme(
              normal: getThemeData(context),
              fullscreen: getThemeData(context),
              child: Video(
                key: key,
                controller: videoController,
                onExitFullscreen: () async => onExit(),
              ),
            )));
  }

  void onExit() async {
    if (exiting) return;
    exiting = true;
    if (widget.channel.mediaType == MediaType.movie &&
        widget.channel.id != null) {
      Sql.setPosition(widget.channel.id!, player.state.position.inSeconds);
    }
    if (key.currentState!.isFullscreen()) {
      await key.currentState!.exitFullscreen();
    }
    try {
      await _airPlayCh.invokeMethod('stop');
    } catch (_) {}
    Navigator.of(context).pop();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void toggleZoom() {
    final videoAspectRatio = player.state.width! / player.state.height!;
    final deviceAspectRatio = MediaQuery.of(context).size.aspectRatio;
    key.currentState!
        .update(aspectRatio: fill ? videoAspectRatio : deviceAspectRatio);
    setState(() {
      fill = !fill;
    });
  }

  Future<void> airPlayToDevice() async {
    try {
      final id = widget.channel.id;
      final headers = id != null ? await Sql.getChannelHeaders(id) : null;
      final position = widget.channel.mediaType == MediaType.movie
          ? player.state.position
          : Duration.zero;
      final connected = await _airPlayCh.invokeMethod('isConnected');
      if (connected != true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select an AirPlay device first.')));
        return;
      }
      final args = {
        'url': widget.channel.url!,
        'startSeconds': position.inSeconds.toDouble(),
        if (headers != null)
          'headers': {
            if (headers.referrer != null) 'Referer': headers.referrer!,
            if (headers.httpOrigin != null) 'Origin': headers.httpOrigin!,
            if (headers.userAgent != null) 'User-Agent': headers.userAgent!,
          },
      };
      final ok = await _airPlayCh.invokeMethod('play', args);
      if (!mounted) return;
      if (ok == true) {
        await player.pause();
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok == true
              ? 'Playing via AirPlay...'
              : 'Failed to play via AirPlay')));
    } catch (e) {
      if (!mounted) return;
      String msg = 'AirPlay error: $e';
      if (e is PlatformException && e.code == 'no_route') {
        msg =
            'No AirPlay device selected. Tap the AirPlay button to connect, then try again.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> castToDevice() async {
    try {
      final id = widget.channel.id;
      final headers = id != null ? await Sql.getChannelHeaders(id) : null;
      final position = widget.channel.mediaType == MediaType.movie
          ? player.state.position
          : Duration.zero;
      final ok = await ChromecastService.loadChannel(
        widget.channel,
        headers: headers != null
            ? {
                if (headers.referrer != null) 'Referer': headers.referrer!,
                if (headers.httpOrigin != null) 'Origin': headers.httpOrigin!,
                if (headers.userAgent != null) 'User-Agent': headers.userAgent!,
              }
            : null,
        start: position,
      );
      if (!mounted) return;
      if (ok) {
        await player.pause();
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              ok ? 'Casting to device...' : 'Failed to send to Cast device')));
    } catch (e) {
      if (!mounted) return;
      String msg = 'Cast error: $e';
      if (e is PlatformException && e.code == 'no_session') {
        msg =
            'No Cast device connected. Tap the Cast button to connect, then try again.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  MaterialVideoControlsThemeData getThemeData(BuildContext context) {
    return MaterialVideoControlsThemeData(
        speedUpOnLongPress: false,
        seekOnDoubleTap: widget.channel.mediaType != MediaType.livestream,
        displaySeekBar: widget.channel.mediaType != MediaType.livestream,
        seekBarMargin: const EdgeInsets.only(bottom: 60),
        seekBarThumbSize: 20,
        seekBarHeight: 10,
        seekGesture: widget.channel.mediaType != MediaType.livestream,
        topButtonBar: [
          IconButton(
            onPressed: onExit,
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.channel.name),
              if (_sourceName != null)
                Text(
                  'Playlist: ${_sourceName!}',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: Colors.white70),
                ),
            ],
          ),
        ],
        bottomButtonBar: [
          IconButton(
            onPressed: openSubtitlesModal,
            icon: const Icon(Icons.subtitles, color: Colors.white, size: 32),
          ),
          SizedBox(
            width: 20,
          ),
          IconButton(
            onPressed: openAudioModal,
            icon: const Icon(Icons.music_note, color: Colors.white, size: 32),
          ),
          SizedBox(
            width: 20,
          ),
          IconButton(
            icon: Icon(Icons.aspect_ratio_outlined,
                color: Colors.white, size: 32),
            onPressed: toggleZoom,
          ),
          SizedBox(width: 20),
          if (Platform.isIOS) ...[
            AirPlayButton(),
            SizedBox(width: 12),
          ],
          ChromecastButton(width: 44, height: 44, tintColor: Colors.white),
        ]);
  }
}
