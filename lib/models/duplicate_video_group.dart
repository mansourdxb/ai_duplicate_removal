// lib/models/duplicate_video_group.dart

import 'package:photo_manager/photo_manager.dart';

class DuplicateVideoGroup {
  final List<AssetEntity> videos;
  final int originalIndex;
  final Set<int> selectedIndices;
  final String duplicateType;
  final String groupId;
  final double totalSize;
  final double confidence;

  DuplicateVideoGroup({
    required this.videos,
    required this.originalIndex,
    required this.selectedIndices,
    required this.duplicateType,
    required this.groupId,
    required this.totalSize,
    required this.confidence,
  });
}
