import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:smart_iptv_pro/backend/sql.dart';
// removed: xtream.dart, memory.dart (no longer used here)
import 'package:smart_iptv_pro/models/channel.dart';
import 'package:smart_iptv_pro/error.dart';
import 'package:smart_iptv_pro/models/media_type.dart';
import 'package:smart_iptv_pro/models/node.dart';
import 'package:smart_iptv_pro/models/node_type.dart';
// removed: player.dart (playback now initiated from DetailsPage)
import 'package:smart_iptv_pro/backend/omdb.dart';
import 'package:smart_iptv_pro/details.dart';

class ChannelTile extends StatefulWidget {
  final Channel channel;
  final BuildContext parentContext;
  final Function(Node node) setNode;
  const ChannelTile(
      {super.key,
      required this.channel,
      required this.setNode,
      required this.parentContext});

  @override
  State<ChannelTile> createState() => _ChannelTileState();
}

class _ChannelTileState extends State<ChannelTile> {
  final FocusNode _focusNode = FocusNode();
  String? _omdbPoster;
  bool _triedOmdb = false;
  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {});
    });
    _maybeFetchPoster();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> favorite() async {
    if (widget.channel.mediaType == MediaType.group) return;
    await Error.tryAsyncNoLoading(() async {
      await Sql.favoriteChannel(widget.channel.id!, !widget.channel.favorite);
      setState(() {
        widget.channel.favorite = !widget.channel.favorite;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Added to favorites"),
        duration: Duration(milliseconds: 500),
      ));
    }, context);
  }

  Future<void> _maybeFetchPoster() async {
    if (_triedOmdb) return;
    _triedOmdb = true;
    if (widget.channel.mediaType == MediaType.movie ||
        widget.channel.mediaType == MediaType.serie) {
      final current = widget.channel.image?.trim();
      if (current == null || current.isEmpty) {
        final poster = await OmdbApi.getPosterByTitle(widget.channel.name);
        if (poster != null) {
          if (mounted) {
            setState(() {
              _omdbPoster = poster;
            });
          }
          if (widget.channel.id != null) {
            await Sql.updateChannelImage(widget.channel.id!, poster);
          }
        }
      }
    }
  }

  Future<void> play() async {
    if (widget.channel.mediaType == MediaType.group) {
      widget.setNode(Node(
          id: widget.channel.id!,
          name: widget.channel.name,
          type: fromMediaType(widget.channel.mediaType)));
      return;
    }
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => DetailsPage(
                  channel: widget.channel,
                )));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = cs.primary;
    final outline = cs.outlineVariant;
    return AnimatedScale(
        scale: _focusNode.hasFocus ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Card(
            clipBehavior: Clip.antiAlias,
            shadowColor: Colors.black54,
            elevation: _focusNode.hasFocus ? 8.0 : 4.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                  color: _focusNode.hasFocus ? accent : outline, width:  _focusNode.hasFocus ? 2 : 1),
            ),
            color: widget.channel.favorite
                ? cs.surfaceContainerHighest
                : cs.surfaceContainer,
            child: InkWell(
              focusNode: _focusNode,
              onLongPress: favorite,
              onTap: () async => await play(),
              borderRadius: BorderRadius.circular(12),
              focusColor: const Color(0x33E50914),
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 3,
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AspectRatio(
                                  aspectRatio: (widget.channel.mediaType == MediaType.livestream)
                                      ? 16 / 9
                                      : 2 / 3,
                                  child: ((widget.channel.image?.trim().isNotEmpty ?? false) || _omdbPoster != null)
                                      ? CachedNetworkImage(
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) =>
                                              Image.asset("assets/icon.png"),
                                          imageUrl: (widget.channel.image?.trim().isNotEmpty ?? false)
                                              ? widget.channel.image!.trim()
                                              : _omdbPoster!,
                                        )
                                      : (_omdbPoster != null
                                          ? CachedNetworkImage(
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) =>
                                                  Image.asset("assets/icon.png"),
                                              imageUrl: _omdbPoster!,
                                            )
                                          : Image.asset(
                                              "assets/icon.png",
                                              fit: BoxFit.cover,
                                            ))))),
                      const SizedBox(width: 12),
                      Expanded(
                          flex: 8,
                          child: LayoutBuilder(builder: (context, constraints) {
                            final style = Theme.of(context).textTheme.bodyMedium!;
                            final fontSize = MediaQuery.of(context)
                                .textScaler
                                .scale(style.fontSize!);
                            final lineHeight = (style.height ?? 1.3) * fontSize;
                            final maxLines =
                                (constraints.maxHeight / lineHeight).floor();
                            return Text(
                              widget.channel.name,
                              overflow: TextOverflow.ellipsis,
                              maxLines: maxLines,
                              style: Theme.of(context).textTheme.bodyMedium,
                            );
                          }))
                    ],
                  )),
            )));
  }
}
