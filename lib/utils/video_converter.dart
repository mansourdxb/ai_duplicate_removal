// lib/utils/video_converter.dart

import '../models/duplicate_video_group.dart';
import '../models/video_group.dart';
import '../models/video.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:io';

class VideoConverter {
  static Future<List<VideoGroup>> fromDuplicateGroups(List<DuplicateVideoGroup> duplicateGroups) async {
    List<VideoGroup> result = [];
    
    for (final duplicateGroup in duplicateGroups) {
      List<Video> videos = [];
      
      for (int i = 0; i < duplicateGroup.videos.length; i++) {
        final AssetEntity asset = duplicateGroup.videos[i];
        
        try {
          final File? file = await asset.file;
          if (file != null) {
            final Video video = Video(
              id: asset.id,
              path: file.path,
              size: asset.size is int ? asset.size as int : 0,
              duration: asset.duration,
              asset: asset,
              width: asset.width,
              height: asset.height,
              title: file.path.split('/').last,
              dateCreated: asset.createDateTime,
            );
            videos.add(video);
          }
        } catch (e) {
          print('Error converting asset to video: $e');
        }
      }
      
    if (videos.isNotEmpty) 
{
  final VideoGroup videoGroup = VideoGroup(
    id: duplicateGroup.groupId,  // Changed from 'groupId' to 'id'
    videos: videos,
    // Remove 'totalSize' as it's a computed property, not a constructor parameter
    // Remove 'confidence' if it's not a parameter in VideoGroup constructor
  );
  
  result.add(videoGroup);
}

    }
    
    return result;
  }
}
