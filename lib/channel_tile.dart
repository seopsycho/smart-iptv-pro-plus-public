import 'package:flutter/material.dart';
import 'package:smart_iptv_pro/backend/sql.dart';
// removed: xtream.dart, memory.dart (no longer used here)
import 'package:smart_iptv_pro/models/channel.dart';
import 'package:smart_iptv_pro/error.dart';
import 'package:smart_iptv_pro/models/media_type.dart';
import 'package:smart_iptv_pro/models/node.dart';
import 'package:smart_iptv_pro/models/node_type.dart';
// removed: player.dart (playback now initiated from DetailsPage)
import 'package:smart_iptv_pro/details.dart';
import 'package:smart_iptv_pro/player.dart';

class ChannelTile extends StatefulWidget {
  final Channel channel;
  final BuildContext parentContext;
  final Function(Node node) setNode;
  final VoidCallback? onFavoriteToggled;
  final ValueChanged<Channel>? onShowDetails;
  const ChannelTile(
      {super.key,
      required this.channel,
      required this.setNode,
      required this.parentContext,
      this.onFavoriteToggled,
      this.onShowDetails});

  @override
  State<ChannelTile> createState() => _ChannelTileState();
}

class _ChannelTileState extends State<ChannelTile> {
  final FocusNode _focusNode = FocusNode();
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
      widget.onFavoriteToggled?.call();
      final msg = widget.channel.favorite
          ? "Added to watchlist"
          : "Removed from watchlist";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 500),
      ));
    }, context);
  }

  Future<void> _maybeFetchPoster() async {
    // No-op: PosterResolver handles image selection at render time
  }

  Future<void> play() async {
    if (widget.channel.mediaType == MediaType.group) {
      widget.setNode(Node(
          id: widget.channel.id!,
          name: widget.channel.name,
          type: fromMediaType(widget.channel.mediaType)));
      return;
    }
    if (widget.channel.mediaType == MediaType.livestream) {
      if (widget.channel.id != null) {
        await Sql.addToHistory(widget.channel.id!);
      }
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => Player(
                    channel: widget.channel,
                  )));
      if (mounted) setState(() {});
      return;
    }
    if (widget.onShowDetails != null) {
      widget.onShowDetails!(widget.channel);
    } else {
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => DetailsPage(
                    channel: widget.channel,
                    onFavoriteToggled: widget.onFavoriteToggled,
                  )));
    }
    if (mounted) setState(() {});
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
              child: Stack(
                children: [
                  Padding(
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
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: Builder(
                                          builder: (context) {
                                            final url = widget.channel.image?.trim();
                                            if (url != null && url.isNotEmpty) {
                                              return Image.network(
                                                url,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Image.asset("assets/icon.png", fit: BoxFit.cover),
                                                loadingBuilder: (_, child, loadingProgress) {
                                                  if (loadingProgress == null) return child;
                                                  return Container(
                                                    color: Theme.of(context).colorScheme.surfaceContainer,
                                                    child: const Center(
                                                      child: CircularProgressIndicator(strokeWidth: 2),
                                                    ),
                                                  );
                                                },
                                              );
                                            }
                                            return Image.asset(
                                              "assets/icon.png",
                                              fit: BoxFit.cover,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  )))),
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
                  if (widget.channel.favorite)
                    const Positioned(
                      top: 6,
                      left: 6,
                      child: IgnorePointer(
                        child: Icon(Icons.favorite, color: Color(0xFFE50914)),
                      ),
                    ),
                ],
              ),
            )));
  }
}
