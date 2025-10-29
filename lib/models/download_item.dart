import 'package:smart_iptv_pro/models/channel.dart';

class DownloadItem {
  final Channel channel;
  final String filePath;
  final int status;
  final int bytes;
  final int totalBytes;

  const DownloadItem({
    required this.channel,
    required this.filePath,
    required this.status,
    required this.bytes,
    required this.totalBytes,
  });

  bool get completed => status == 1 || (totalBytes > 0 && bytes >= totalBytes);
  double get progress => totalBytes > 0 ? bytes / totalBytes : 0.0;
}
