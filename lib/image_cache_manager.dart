import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ImageCacheManager {
  static const key = 'imagesCacheV2';
  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 500,
      // Use default repo/path to ensure writable DB on all platforms
    ),
  );
}
