// lib/models/video_group.dart

import 'video.dart';

class VideoGroup {
  final String id;
  final List<Video> videos;
  final int bestVideoIndex;
  
  // Calculate total size property
  double get totalSize => videos.fold(
  0.0, 
  (sum, video) => sum + (video.size ?? 0)
  );

  const VideoGroup({
    required this.id,
    required this.videos,
    this.bestVideoIndex = 0,
  });
}
