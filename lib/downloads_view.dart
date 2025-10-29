import 'dart:io';
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:smart_iptv_pro/backend/sql.dart';
import 'package:smart_iptv_pro/models/download_item.dart';
import 'package:smart_iptv_pro/player.dart';
import 'package:smart_iptv_pro/services/downloads_service.dart';

class DownloadsView extends StatefulWidget {
  final bool embedded;
  const DownloadsView({super.key, this.embedded = false});

  @override
  State<DownloadsView> createState() => _DownloadsViewState();
}

class _DownloadsViewState extends State<DownloadsView> {
  List<DownloadItem> items = [];
  bool loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await Sql.getAllDownloads();
    if (!mounted) return;
    setState(() {
      items = list;
      loading = false;
    });
    _ensureTicker();
  }

  Future<void> _play(DownloadItem di) async {
    final file = File(di.filePath);
    if (!(await file.exists())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File missing. Removing from downloads.')), 
      );
      await DownloadsService.removeDownload(di.channel.id!);
      await _load();
      return;
    }
    final localUrl = Uri.file(di.filePath).toString();
    final ch = di.channel;
    ch.url = localUrl;
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Player(channel: ch),
      ),
    );
  }

  Future<void> _remove(DownloadItem di) async {
    await DownloadsService.removeDownload(di.channel.id!);
    await _load();
  }

  void _ensureTicker() {
    final active = items.any((d) => d.status == 0);
    if (active && _timer == null) {
      _timer = Timer.periodic(const Duration(milliseconds: 800), (_) async {
        final list = await Sql.getAllDownloads();
        if (!mounted) return;
        setState(() {
          items = list;
        });
        if (!items.any((d) => d.status == 0)) {
          _timer?.cancel();
          _timer = null;
        }
      });
    }
    if (!active && _timer != null) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  Widget _buildList(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) return const Center(child: Text('No downloads yet'));
    return ListView.separated(
      itemBuilder: (context, index) {
        final di = items[index];
        final image = di.channel.image;
        final hasTotal = di.totalBytes > 0;
        final sub = di.completed
            ? 'Completed'
            : (hasTotal ? '${((di.progress) * 100).toStringAsFixed(0)}%' : 'Downloading...');
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 80,
              height: 45,
              child: (image?.trim().isNotEmpty ?? false)
                  ? CachedNetworkImage(
                      imageUrl: image!.trim(),
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      child: const Icon(Icons.movie),
                    ),
            ),
          ),
          title: Text(di.channel.name),
          subtitle: Text(sub),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: di.completed ? () => _play(di) : null,
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _remove(di),
              ),
            ],
          ),
        );
      },
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemCount: items.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildList(context);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: _buildList(context),
    );
  }
}
