import 'package:smart_iptv_pro/models/media_type.dart';

class Channel {
  int? id;
  String name;
  int? groupId;
  String? group;
  String? image;
  String? url;
  MediaType mediaType;
  int sourceId;
  bool favorite;
  int? seriesId;
  int? streamId;
  int? createdAt;
  int? updatedAt;

  Channel({
    this.id,
    required this.name,
    this.group,
    this.groupId,
    this.image,
    this.url,
    required this.mediaType,
    required this.sourceId,
    required this.favorite,
    this.seriesId,
    this.streamId,
    this.createdAt,
    this.updatedAt,
  });
}
