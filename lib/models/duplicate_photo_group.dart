// lib/models/duplicate_photo_group.dart
import 'package:photo_manager/photo_manager.dart';

class DuplicatePhotoGroup {
  final List<AssetEntity> photos;
  final int originalIndex; // Index of the original (keep this one)
  final Set<int> selectedIndices; // Indices of duplicates to delete
  final String duplicateType; // 'exact', 'near_exact', 'resolution_variant'
  final String groupId;
  final double totalSize; // Size in GB
  final double confidence; // 0.0 to 1.0 how confident we are these are duplicates

  DuplicatePhotoGroup({
    required this.photos,
    required this.originalIndex,
    required this.selectedIndices,
    required this.duplicateType,
    required this.groupId,
    required this.totalSize,
    this.confidence = 1.0,
  });

  // Get photos that will be deleted
  List<AssetEntity> get duplicatesToDelete {
    return selectedIndices.map((index) => photos[index]).toList();
  }

  // Get the original photo to keep
  AssetEntity get originalPhoto => photos[originalIndex];

  // Calculate space that will be freed
  double get spaceSaved {
    double saved = 0.0;
    for (int index in selectedIndices) {
      if (index < photos.length) {
        AssetEntity photo = photos[index];
        int pixels = photo.width * photo.height;
        double estimatedMB = _estimatePhotoSize(pixels);
        saved += estimatedMB;
      }
    }
    return saved / 1024; // Convert MB to GB
  }

  static double _estimatePhotoSize(int pixels) {
    if (pixels < 1000000) return 0.5;
    else if (pixels < 3000000) return 1.5;
    else if (pixels < 8000000) return 3.0;
    else if (pixels < 20000000) return 6.0;
    else return 12.0;
  }
}
