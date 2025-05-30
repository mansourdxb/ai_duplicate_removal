import 'package:photo_manager/photo_manager.dart';

class SimilarPhotoGroup {
  final String groupId;
  final List<AssetEntity> photos;
  final String reason;
  final int bestPhotoIndex;
  final double totalSize;
  final List<int> selectedIndices;

  SimilarPhotoGroup({
    required this.groupId,
    required this.photos,
    required this.reason,
    this.bestPhotoIndex = 0, // Default to first photo
    this.totalSize = 0.0,
    List<int>? selectedIndices,
  }) : selectedIndices = selectedIndices ?? [];
}
