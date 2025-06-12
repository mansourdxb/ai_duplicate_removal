import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
// If using file saving, also add:
// import 'package:path_provider/path_provider.dart';

class ThumbnailService {
  // Singleton pattern
  static final ThumbnailService _instance = ThumbnailService._internal();
  factory ThumbnailService() => _instance;
  ThumbnailService._internal();

  // Cache to store generated thumbnails
  final Map<String, Uint8List> _cache = {};
  
  // Queue to manage pending thumbnail generation requests
  final Set<String> _pendingRequests = {};

  // Get thumbnail method
  Future<Uint8List?> getThumbnail(
    String videoPath, {
    int maxHeight = 240,
    int maxWidth = 240,
    int quality = 70,
    int timeMs = 0,
    Function(Uint8List?)? onComplete,
  }) async {
    // Check cache first
    if (_cache.containsKey(videoPath)) {
      return _cache[videoPath];
    }
    
    // Check if already processing
    if (_pendingRequests.contains(videoPath)) {
      return null;
    }
    
    _pendingRequests.add(videoPath);
    
    try {
      // Generate the thumbnail
      final bytes = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxHeight: maxHeight,
        maxWidth: maxWidth,
        quality: quality,
        timeMs: timeMs,
      );
      
      // Store in cache if successful
      if (bytes != null) {
        _cache[videoPath] = bytes;
      }
      
      // Call completion callback if provided
      if (onComplete != null) {
        onComplete(bytes);
      }
      
      return bytes;
    } catch (e) {
      print('Error generating thumbnail: $e');
      return null;
    } finally {
      _pendingRequests.remove(videoPath);
    }
  }

  // Additional methods for cache management
  void clearCache() {
    _cache.clear();
  }
  
  void trimCache({int keepRecentCount = 20}) {
    if (_cache.length <= keepRecentCount) {
      return; // No need to trim
    }
    
    // Get list of keys
    final keys = _cache.keys.toList();
    
    // Remove oldest entries
    for (int i = 0; i < keys.length - keepRecentCount; i++) {
      _cache.remove(keys[i]);
    }
  }
  
  void cancelOperations() {
    _pendingRequests.clear();
  }
}
