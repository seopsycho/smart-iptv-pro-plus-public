import 'package:flutter/services.dart';

class OrientationService {
  static const MethodChannel _channel = MethodChannel('com.smartiptv.pro/orientation');
  
  static Future<void> enableLandscape() async {
    try {
      await _channel.invokeMethod('enableLandscape');
    } catch (e) {
      print('Failed to enable landscape: $e');
    }
  }
  
  static Future<void> disableLandscape() async {
    try {
      await _channel.invokeMethod('disableLandscape');
    } catch (e) {
      print('Failed to disable landscape: $e');
    }
  }
  
  static Future<void> forcePortrait() async {
    try {
      await _channel.invokeMethod('forcePortrait');
    } catch (e) {
      print('Failed to force portrait: $e');
    }
  }
}
