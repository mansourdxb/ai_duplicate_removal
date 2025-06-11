import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:io'; // Add this import for File class
import 'dart:math' as math; // For the math functions in _formatSize

class Video {
  final String id;
  final String path;
  final String duration;
  final String size;
  final AssetEntity asset; // Reference to the original AssetEntity
  Uint8List? thumbnailBytes;
  
  Video({
    required this.id,
    required this.path,
    required this.duration,
    required this.size,
    required this.asset,
    this.thumbnailBytes,
  });
  
// Create a Video from an AssetEntity
static Future<Video> fromAssetEntity(AssetEntity asset) async {
  final File? file = await asset.file;
  
  // Get file size in bytes
  int fileSizeInBytes = 0;
  if (file != null) {
    try {
      fileSizeInBytes = await file.length();
    } catch (e) {
      print('Error getting file size: $e');
    }
  }
  
  return Video(
    id: asset.id,
    path: file?.path ?? '',
    duration: '${asset.duration}s',
    size: _formatSize(fileSizeInBytes), // Now using the correct file size in bytes
    asset: asset,
  );
}
  
  Future<void> generateThumbnail() async {
    try {
      if (path.isNotEmpty) {
        thumbnailBytes = await VideoThumbnail.thumbnailData(
          video: path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 128,
          quality: 25,
        );
      } else {
        // Fallback to using the asset's thumbnail if path is not available
        thumbnailBytes = await asset.thumbnailData;
      }
    } catch (e) {
      print('Error generating thumbnail for $path: $e');
      // Fallback to asset thumbnail
      try {
        thumbnailBytes = await asset.thumbnailData;
      } catch (e) {
        print('Error getting asset thumbnail: $e');
      }
    }
  }
  
  // Helper to format file size
  static String _formatSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (math.log(bytes) / math.log(1024)).floor();
    return '${(bytes / math.pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }
}

class VideoGroup {
  final String id;
  final List<AssetEntity> videos; // Keep using AssetEntity for compatibility
  final int bestVideoIndex;
  final Set<int> selectedIndices;
  final String reason;
  final String groupId;
  final double totalSize;
  Uint8List? _cachedThumbnail;
  
  VideoGroup({
    required this.videos,
    required this.bestVideoIndex,
    required this.selectedIndices,
    required this.reason,
    required this.groupId,
    required this.totalSize,
  }) : id = groupId;
  
  Future<Uint8List?> getThumbnail() async {
    if (_cachedThumbnail != null) return _cachedThumbnail;
    
    if (videos.isEmpty) return null;
    
    try {
      _cachedThumbnail = await videos[0].thumbnailData;
      return _cachedThumbnail;
    } catch (e) {
      print('Error getting thumbnail for group $id: $e');
      return null;
    }
  }
}
