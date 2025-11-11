import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ImageCacheManager {
  static const key = 'imagesCacheV3';
  static CacheManager? _instance;
  
  static CacheManager get instance {
    _instance ??= CacheManager(
      Config(
        key,
        stalePeriod: const Duration(days: 30),
        maxNrOfCacheObjects: 500,
        fileService: HttpFileService(),
      ),
    );
    return _instance!;
  }
  
  static Future<void> initialize() async {
    _instance = CacheManager(
      Config(
        key,
        stalePeriod: const Duration(days: 30),
        maxNrOfCacheObjects: 500,
        fileService: HttpFileService(),
      ),
    );
    print('ImageCacheManager initialized successfully');
  }
}
