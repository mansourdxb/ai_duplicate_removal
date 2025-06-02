import 'package:photo_manager/photo_manager.dart';

class SimilarPhotoGroup {
  final List<AssetEntity> photos;
  final int bestPhotoIndex;
  final Set<int> selectedIndices;
  final String reason;
  final String groupId;
  double totalSize;
  
  SimilarPhotoGroup({
    required this.photos,
    required this.bestPhotoIndex,
    required this.selectedIndices,
    required this.reason,
    required this.groupId,
    this.totalSize = 0.0,
  });
}
