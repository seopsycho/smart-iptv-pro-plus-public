import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:open_tv/backend/sql.dart';
// removed: xtream.dart, memory.dart (no longer used here)
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/error.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/models/node.dart';
import 'package:open_tv/models/node_type.dart';
// removed: player.dart (playback now initiated from DetailsPage)
import 'package:open_tv/backend/omdb.dart';
import 'package:open_tv/details.dart';

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
    return Card(
        elevation: _focusNode.hasFocus ? 8.0 : 4.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        color: widget.channel.favorite
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Theme.of(context).colorScheme.surfaceContainer,
        child: InkWell(
          focusNode: _focusNode,
          onLongPress: favorite,
          onTap: () async => await play(),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
              padding: const EdgeInsets.all(5),
              child: Row(
                children: [
                  Expanded(
                      flex: 3,
                      child: Align(
                          alignment: Alignment.centerLeft,
                          child: ((widget.channel.image?.trim().isNotEmpty ?? false) || _omdbPoster != null)
                              ? CachedNetworkImage(
                                  width: 1000,
                                  fit: BoxFit.contain,
                                  errorWidget: (_, __, ___) =>
                                      Image.asset("assets/icon.png"),
                                  imageUrl: (widget.channel.image?.trim().isNotEmpty ?? false)
                                      ? widget.channel.image!.trim()
                                      : _omdbPoster!,
                                )
                              : (_omdbPoster != null
                                  ? CachedNetworkImage(
                                      width: 1000,
                                      fit: BoxFit.contain,
                                      errorWidget: (_, __, ___) =>
                                          Image.asset("assets/icon.png"),
                                      imageUrl: _omdbPoster!,
                                    )
                                  : Image.asset(
                                      "assets/icon.png",
                                      fit: BoxFit.contain,
                                    )))),
                  const Expanded(flex: 1, child: SizedBox()),
                  Expanded(
                      flex: 8,
                      child: LayoutBuilder(builder: (context, constraints) {
                        final style = Theme.of(context).textTheme.bodyMedium!;
                        final fontSize = MediaQuery.of(context)
                            .textScaler
                            .scale(style.fontSize!);
                        final lineHeight = style.height! * fontSize;
                        final maxLines =
                            (constraints.maxHeight / lineHeight).floor();
                        return Text(
                          widget.channel.name,
                          overflow: TextOverflow.ellipsis,
                          maxLines: maxLines,
                        );
                      }))
                ],
              )),
        ));
  }
}
