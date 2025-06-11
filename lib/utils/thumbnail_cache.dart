// lib/utils/thumbnail_cache.dart

import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:io';

class ThumbnailCache {
  static final _cache = <String, Uint8List>{};
  
  // Get thumbnail from cache or generate it
  static Future<Uint8List?> generateAndCacheThumbnail(AssetEntity asset) async {
    final String cacheKey = 'thumb_${asset.id}';
    
    // Check in-memory cache first
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }
    
    try {
      // Try to get from photo_manager first (faster)
      Uint8List? thumbnail = await asset.thumbnailData;
      
      // If that fails, generate from video file
      if (thumbnail == null) {
        final File? file = await asset.file;
        if (file != null) {
          thumbnail = await VideoThumbnail.thumbnailData(
            video: file.path,
            imageFormat: ImageFormat.JPEG,
            quality: 50,
            maxWidth: 200,
            timeMs: (asset.duration / 3).round(), // Take thumbnail from 1/3 of video
          );
        }
      }
      
      if (thumbnail != null) {
        // Store in memory cache
        _cache[cacheKey] = thumbnail;
        return thumbnail;
      }
    } catch (e) {
      print('Error generating thumbnail for ${asset.id}: $e');
    }
    
    return null;
  }
  
  // Get thumbnail from cache only
  static Future<Uint8List?> getThumbnail(String cacheKey) async {
    return _cache[cacheKey];
  }
  
  // Set thumbnail in cache
  static Future<void> setThumbnail(String cacheKey, Uint8List thumbnail) async {
    _cache[cacheKey] = thumbnail;
  }
  
  // Clear cache
  static void clearCache() {
    _cache.clear();
  }
}
