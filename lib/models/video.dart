// lib/models/video.dart

import 'package:photo_manager/photo_manager.dart';

class Video {
  final String id;
  final String path;
  final int size;
  final int duration;
  final AssetEntity asset;
  final int width;
  final int height;
  final String title;
  final DateTime dateCreated;

  Video({
    required this.id,
    required this.path,
    required this.size,
    required this.duration,
    required this.asset,
    required this.width,
    required this.height,
    required this.title,
    required this.dateCreated,
  });
}
