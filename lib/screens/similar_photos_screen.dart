import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/similar_photo_group.dart';
import 'dart:math' as math; // ✅ Add this import
import 'dart:async'; // ✅ ADD THIS if not already present

class PhotoData {
  final AssetEntity asset;
  final Uint8List thumbnail;
  final int index;
  final double size;
  
  PhotoData({
    required this.asset,
    required this.thumbnail,
    required this.index,
    required this.size,
  });
}

enum PhotoSortOption {
  newest,
  oldest,
  largest,
  smallest,
}

extension PhotoSortOptionExtension on PhotoSortOption {
  String get displayName {
    switch (this) {
      case PhotoSortOption.newest:
        return 'Newest';
      case PhotoSortOption.oldest:
        return 'Oldest';
      case PhotoSortOption.largest:
        return 'Largest';
      case PhotoSortOption.smallest:
        return 'Smallest';
    }
  }
  
  IconData get icon {
    switch (this) {
      case PhotoSortOption.newest:
        return Icons.schedule;
      case PhotoSortOption.oldest:
        return Icons.history;
      case PhotoSortOption.largest:
        return Icons.photo_size_select_large;
      case PhotoSortOption.smallest:
        return Icons.photo_size_select_small;
    }
  }
}

class SimilarPhotosScreen extends StatefulWidget {
  // ✅ FIXED: Change from List<List<PhotoModel>> to List<SimilarPhotoGroup>
  final List<SimilarPhotoGroup> preGroupedPhotos;
  final int totalCount;
  final double totalSize;

  const SimilarPhotosScreen({
    Key? key,
    required this.preGroupedPhotos, // Now accepts correct type
    required this.totalCount,
    required this.totalSize,
  }) : super(key: key);

  @override
  _SimilarPhotosScreenState createState() => _SimilarPhotosScreenState();
}



class _SimilarPhotosScreenState extends State<SimilarPhotosScreen> {
  List<SimilarPhotoGroup> photoGroups = [];
  bool isLoading = true;
  int selectedCount = 0;
  double selectedSize = 0.0;
  PhotoSortOption _currentSortOption = PhotoSortOption.newest;
  bool isCalculatingSize = false;
  bool _isSelectingAll = false; // ✅ Add this flag
   // ✅ ADD THIS LINE HERE
  Timer? _debounceTimer;
  Timer? _sizeCalculationTimer;
  // ✅ Cache photo sizes to avoid repeated calculations
  final Map<String, double> _photoSizeCache = {};


// ✅ ADD THIS METHOD
// ✅ FIND AND UPDATE YOUR _debouncedSetState() METHOD
void _debouncedSetState(VoidCallback fn) {
  _debounceTimer?.cancel();
  _debounceTimer = Timer(const Duration(milliseconds: 16), () { // ✅ Reduced from 50ms to 16ms
    if (mounted) {
      setState(fn);
    }
  });
}


  // ✅ FIXED: Updated debug method with correct parameter names
  Future<void> _debugSimilarPhotosScreen() async {
    print('=== SIMILAR PHOTOS SCREEN DEBUG ===');
    print('📊 Pre-grouped photos provided: ${widget.preGroupedPhotos.length} groups');
    print('📊 Total count parameter: ${widget.totalCount}');
    print('📊 Total size parameter: ${widget.totalSize}MB');
    
    if (widget.preGroupedPhotos.isNotEmpty) {
      int totalPhotosInPreGroups = 0;
      for (var group in widget.preGroupedPhotos) {
        totalPhotosInPreGroups += group.photos.length;
        //print('   Pre-group "${group.reason}": ${group.photos.length} photos');
      }
      print('📊 Total photos in pre-groups: $totalPhotosInPreGroups');
      print('✅ Using pre-grouped photos - NO RE-ANALYSIS NEEDED');
    } else {
      print('❌ ERROR: No pre-grouped photos available');
    }
    print('=== END SIMILAR PHOTOS SCREEN DEBUG ===\n');
  }

// ✅ Add this method to calculate group sizes
Future<void> _calculateGroupSizes() async {
  print('🔄 Calculating group sizes...');
  
  for (int i = 0; i < photoGroups.length; i++) {
    final group = photoGroups[i];
    double totalSize = 0.0;
    
    for (var photo in group.photos) {
      totalSize += await _getPhotoSizeFromAsset(photo);
    }
    
    group.totalSize = totalSize;
    
    // Update UI progressively for better UX
    if (mounted) {
      setState(() {});
    }
    
    // Small delay to prevent UI blocking
    await Future.delayed(const Duration(milliseconds: 5));
  }
  
  print('✅ Group sizes calculated');
}


 @override
  void initState() {
    super.initState();
    _debugSimilarPhotosScreen();
    
    if (widget.preGroupedPhotos.isNotEmpty) {
      print('✅ Using pre-grouped photos from Home screen');
      _usePreGroupedPhotos();
    } else {
      print('❌ CRITICAL ERROR: No pre-grouped photos provided!');
      _showErrorAndReturn();
    }
  }


  // **NEW: Show error instead of falling back to re-analysis**
 void _showErrorAndReturn() {
  setState(() {
    isLoading = false;
  });
  
  WidgetsBinding.instance.addPostFrameCallback((_) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: const Text(
          'No photo groups available. Please go back to the home screen and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to home
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  });
}

void _usePreGroupedPhotos() async {
  print('🚀 _usePreGroupedPhotos() called - NO RE-ANALYSIS');
  
  setState(() {
    photoGroups = List.from(widget.preGroupedPhotos);
    isLoading = false;
  });
  
  // ✅ Calculate group sizes in background
  _calculateGroupSizes();
  
  // ✅ Calculate initial selection without blocking UI
  _calculateInitialSelectionOptimized();
  _applySorting();
  
  print('✅ Pre-grouped photos loaded instantly');
}

void _calculateInitialSelectionOptimized() async {
  print('🔄 _calculateInitialSelection() called');
  
  int tempCount = 0;
  
  // First pass: select photos quickly
  for (var group in photoGroups) {
    group.selectedIndices.clear();
    
    for (int i = 0; i < group.photos.length; i++) {
      if (i != group.bestPhotoIndex) {
        group.selectedIndices.add(i);
        tempCount++;
      }
    }
  }
  
  setState(() {
    selectedCount = tempCount;
    selectedSize = 0.0; // Will be calculated in background
  });
  
  // Calculate sizes in background
  _calculateInitialSizes();
  
  print('📊 Initial selection: $tempCount photos selected');
}

// ✅ FIXED: Safe initial size calculation
// ✅ FIXED: Safe initial size calculation
// ✅ UPDATE THIS METHOD
// ✅ REPLACE YOUR EXISTING _calculateInitialSizes() METHOD
void _calculateInitialSizes() async {
  double tempSize = 0.0;
  
  List<SimilarPhotoGroup> groupsSnapshot = List.from(photoGroups);
  
  for (var group in groupsSnapshot) {
    Set<int> selectedSnapshot = Set.from(group.selectedIndices);
    
    for (int index in selectedSnapshot) {
      if (index < group.photos.length) {
        tempSize += await _getPhotoSizeFromAsset(group.photos[index]);
      }
    }
  }
  
  // ✅ UPDATE UI ONLY ONCE at the end
  if (mounted) {
    setState(() {
      selectedSize = tempSize;
    });
  }
}



  // **REMOVE THIS METHOD - We don't want fallback re-analysis**
  // void _groupSimilarPhotos() async { ... } // DELETE THIS ENTIRE METHOD

  Future<int> _findBestPhotoIndex(List<AssetEntity> photos) async {
    if (photos.length <= 1) return 0;
    
    int bestIndex = 0;
    double bestScore = 0;
    
    for (int i = 0; i < photos.length; i++) {
      double score = 0;
      final photo = photos[i];
      
      // 1. Resolution score (most important factor)
      final width = photo.width ?? 0;
      final height = photo.height ?? 0;
      final totalPixels = width * height;
      score += totalPixels / 100000.0; // Normalize to reasonable range
      
      // 2. Aspect ratio preference
      if (width > 0 && height > 0) {
        final aspectRatio = width / height;
        // Prefer standard ratios
        if (aspectRatio >= 0.7 && aspectRatio <= 1.5) {
          score += 50; // Good aspect ratio bonus
        }
        // Penalize very wide or very tall images
        if (aspectRatio < 0.3 || aspectRatio > 3.0) {
          score -= 30;
        }
      }
      
      // 3. File size consideration (but not too heavy)
      try {
        final file = await photo.file;
        if (file != null) {
          final sizeInBytes = await file.length();
          final sizeInMB = sizeInBytes / (1024 * 1024);
          
          // Sweet spot: 2-8MB is usually good quality
          if (sizeInMB >= 2 && sizeInMB <= 8) {
            score += 30;
          } else if (sizeInMB > 8) {
            score += 20; // Large files are good but not always better
          } else if (sizeInMB < 0.5) {
            score -= 20; // Very small files are often low quality
          }
        }
      } catch (e) {
        // If we can't get file info, no penalty
      }
      
      // 4. Slight preference for newer photos (tie-breaker)
      final date = photo.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final hoursSinceEpoch = date.millisecondsSinceEpoch / (1000 * 60 * 60);
      score += hoursSinceEpoch * 0.0001; // Very small bonus for recency
      
      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }
    
    return bestIndex;
  }

  // **REMOVE THIS METHOD - Not needed anymore**
  // Future<List<SimilarPhotoGroup>> _createSimpleGroups(List<PhotoData> photoDataList) async { ... }

  // Add this helper method
  // ✅ Optimized photo size calculation with caching
  Future<double> _getPhotoSizeFromAsset(AssetEntity asset) async {
    // Check cache first
    if (_photoSizeCache.containsKey(asset.id)) {
      return _photoSizeCache[asset.id]!;
    }
    
    try {
      final file = await asset.file;
      if (file != null && await file.exists()) {
        final sizeInBytes = await file.length();
        final sizeInMB = sizeInBytes / (1024 * 1024);
        
        // Cache the result
        _photoSizeCache[asset.id] = sizeInMB;
        return sizeInMB;
      } else {
        _photoSizeCache[asset.id] = 0.0;
        return 0.0;
      }
    } catch (e) {
      _photoSizeCache[asset.id] = 0.0;
      return 0.0;
    }
  }

  Future<double> _getPhotoSize(SimilarPhotoGroup group, int photoIndex) async {
    try {
      final photo = group.photos[photoIndex];
      final file = await photo.file;
      if (file != null && await file.exists()) {
        final sizeInBytes = await file.length();
        return sizeInBytes / (1024 * 1024); // Convert to MB
      } else {
        // Photo no longer exists (was deleted)
        print('⚠️ Photo ${photo.id} no longer exists - was deleted');
        return 0.0; // Return 0 for deleted photos
      }
    } catch (e) {
      // Photo was deleted or doesn't exist
      print('⚠️ Photo no longer accessible: $e');
      return 0.0; // Return 0 for inaccessible photos
    }
  }
  // ✅ FIXED: Prevent concurrent modifications in toggle
// ✅ REPLACE YOUR EXISTING _togglePhotoSelection() METHOD
void _togglePhotoSelection(int groupIndex, int photoIndex) {
  final group = photoGroups[groupIndex];
  
  // ✅ Batch state changes - no intermediate setState calls
  bool wasSelected = group.selectedIndices.contains(photoIndex);
  int countChange = 0;
  
  if (wasSelected) {
    group.selectedIndices.remove(photoIndex);
    countChange = -1;
  } else {
    // ✅ Prevent selecting the best photo
    if (photoIndex != group.bestPhotoIndex) {
      group.selectedIndices.add(photoIndex);
      countChange = 1;
    }
  }
  
  // ✅ SINGLE setState call with all changes
  if (countChange != 0) {
    setState(() {
      selectedCount += countChange;
    });
    
    // ✅ Calculate size in background WITHOUT UI updates during scroll
    _updateSizeInBackgroundSilent();
  }
}
// ✅ ADD THIS NEW METHOD - NO UI UPDATES DURING SCROLL
void _updateSizeInBackgroundSilent() async {
  // ✅ Debounce to prevent excessive calculations during rapid scrolling
  _sizeCalculationTimer?.cancel();
  _sizeCalculationTimer = Timer(const Duration(milliseconds: 300), () async {
    double tempSize = 0.0;
    
    for (var group in photoGroups) {
      for (int index in Set.from(group.selectedIndices)) {
        if (index < group.photos.length) {
          tempSize += await _getPhotoSizeFromAsset(group.photos[index]);
        }
      }
    }
    
    // ✅ Update UI only once when calculation is complete
    if (mounted) {
      setState(() {
        selectedSize = tempSize;
      });
    }
  });
}


// ✅ NEW: Safe size update method
// ✅ UPDATE THIS METHOD
void _updateSizeForPhotoSafe(AssetEntity photo, bool isSelected) async {
  try {
    final size = await _getPhotoSizeFromAsset(photo);
    
    if (mounted) {
      // ✅ CHANGED: Use debounced setState
      _debouncedSetState(() {
        if (isSelected) {
          selectedSize += size;
        } else {
          selectedSize = math.max(0, selectedSize - size);
        }
      });
    }
  } catch (e) {
    print('Error updating photo size: $e');
  }
}


void _updateSizeForPhoto(AssetEntity photo, bool isSelected) async {
  final size = await _getPhotoSizeFromAsset(photo);
  
  if (mounted) {
    setState(() {
      if (isSelected) {
        selectedSize += size;
      } else {
        selectedSize -= size;
      }
    });
  }
}
// ✅ FIXED: Prevent concurrent selectAll operations
// ✅ FIXED: Only select photos that should be selectable
// ✅ REPLACE YOUR EXISTING _selectAll() METHOD WITH THIS
Future<void> _selectAll() async {
  if (_isSelectingAll) return;
  
  setState(() {
    _isSelectingAll = true;
  });
  
  try {
    int tempSelectedCount = 0;
    
    // ✅ Create a snapshot to prevent concurrent modification
    List<SimilarPhotoGroup> groupsSnapshot = List.from(photoGroups);
    
    for (var group in groupsSnapshot) {
      group.selectedIndices.clear();
      
      // ✅ CRITICAL: Only select photos that are NOT the best photo
      for (int i = 0; i < group.photos.length; i++) {
        if (i != group.bestPhotoIndex) { // ✅ Skip best photo
          group.selectedIndices.add(i);
          tempSelectedCount++;
        }
      }
    }
    
    // ✅ UPDATE UI ONLY ONCE with final counts
    setState(() {
      selectedCount = tempSelectedCount;
      selectedSize = 0.0; // Will be calculated in background
    });
    
    // ✅ Calculate sizes in background WITHOUT UI updates
    _calculateSizesInBackgroundSilent();
    
  } finally {
    setState(() {
      _isSelectingAll = false;
    });
  }
}
// ✅ ADD THIS NEW METHOD
void _calculateSizesInBackgroundSilent() async {
  double tempSize = 0.0;
  
  for (var group in photoGroups) {
    for (int index in Set.from(group.selectedIndices)) {
      tempSize += await _getPhotoSizeFromAsset(group.photos[index]);
      
      // ✅ NO UI UPDATES during calculation - only at the end
    }
  }
  
  // ✅ UPDATE UI ONLY ONCE with final size
  if (mounted) {
    setState(() {
      selectedSize = tempSize;
    });
  }
}

// ✅ NEW: Get total selectable photos (excluding best photos)
// ✅ REPLACE YOUR EXISTING METHOD WITH THIS
int _getTotalSelectablePhotos() {
  int total = 0;
  for (var group in photoGroups) {
    // Count all photos except the best one in each group
    total += group.photos.length - 1; // -1 because we don't select the best photo
  }
  return total;
}


// ✅ Keep existing method for total count
// ✅ YOUR EXISTING METHOD SHOULD LOOK LIKE THIS
int _getTotalPhotos() {
  int total = 0;
  for (var group in photoGroups) {
    total += group.photos.length; // Count ALL photos
  }
  return total;
}



// ✅ Calculate sizes without blocking UI
// ✅ FIXED: Safe iteration over selectedIndices
// ✅ REPLACE YOUR EXISTING METHOD WITH THIS
// ✅ REPLACE YOUR EXISTING _calculateSizesInBackground() METHOD
void _calculateSizesInBackground() async {
  double tempSize = 0.0;
  int processedPhotos = 0;
  int totalPhotos = selectedCount;
  
  for (var group in photoGroups) {
    for (int index in Set.from(group.selectedIndices)) {
      tempSize += await _getPhotoSizeFromAsset(group.photos[index]);
      processedPhotos++;
      
      // ✅ REDUCED: Update UI only every 20 photos instead of every few photos
      if (processedPhotos % 20 == 0 || processedPhotos == totalPhotos) {
        _debouncedSetState(() {
          selectedSize = tempSize;
        });
      }
    }
  }
  
  // ✅ Final update to ensure accuracy
  _debouncedSetState(() {
    selectedSize = tempSize;
  });
}



 void _deselectGroup(int groupIndex) {
  final group = photoGroups[groupIndex];
  
  setState(() {
    selectedCount -= group.selectedIndices.length;
    group.selectedIndices.clear();
  });
  
  // Recalculate size in background
  _recalculateSelectionOptimized();
}

// ✅ REPLACE YOUR EXISTING _deselectAll() METHOD
void _deselectAll() {
  // ✅ SINGLE setState call - no background calculations needed
  setState(() {
    selectedCount = 0;
    selectedSize = 0.0;
    
    for (var group in photoGroups) {
      group.selectedIndices.clear();
    }
  });
}


// ✅ FIXED: Safe recalculation
void _recalculateSelectionOptimized() async {
  double tempSize = 0.0;
  
  // ✅ Create snapshots to prevent concurrent modification
  for (var group in List.from(photoGroups)) {
    for (int index in Set.from(group.selectedIndices)) {
      if (index < group.photos.length) {
        tempSize += await _getPhotoSizeFromAsset(group.photos[index]);
      }
    }
  }
  
  if (mounted) {
    setState(() {
      selectedSize = tempSize;
    });
  }
}

// ✅ NEW: Safe operation wrapper
Future<void> _performSafeSetOperation(Function operation) async {
  try {
    await operation();
  } catch (e) {
    if (e.toString().contains('Concurrent modification')) {
      print('⚠️ Concurrent modification detected, retrying...');
      // Retry once after a small delay
      await Future.delayed(const Duration(milliseconds: 50));
      try {
        await operation();
      } catch (retryError) {
        print('❌ Retry failed: $retryError');
      }
    } else {
      print('❌ Operation error: $e');
    }
  }
}

  Future<void> _recalculateSelection() async {
    selectedCount = 0;
    selectedSize = 0.0;
    
    for (var group in photoGroups) {
      selectedCount += group.selectedIndices.length;
      for (int index in group.selectedIndices) {
        selectedSize += await _getPhotoSize(group, index);
      }
    }
  }

  

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SortOptionsBottomSheet(
        currentOption: _currentSortOption,
 onOptionSelected: (option) {
  // ✅ SIMPLE setState - no debouncing needed
  setState(() {
    _currentSortOption = option;
  });
  _applySorting(); // This will now be instant
},
      ),
    );
  }

// ✅ REPLACE YOUR EXISTING _applySorting() METHOD WITH THIS
// ✅ REPLACE YOUR EXISTING _applySorting() METHOD
void _applySorting() {
  // ✅ NO setState() wrapper here!
  switch (_currentSortOption) {
    case PhotoSortOption.newest:
      _sortGroupsByNewest();
      break;
    case PhotoSortOption.oldest:
      _sortGroupsByOldest();
      break;
    case PhotoSortOption.largest:
      _sortGroupsByLargest();
      break;
    case PhotoSortOption.smallest:
      _sortGroupsBySmallest();
      break;
  }
}



// ✅ REPLACE YOUR EXISTING _sortGroupsBySmallest() METHOD
// ✅ REPLACE YOUR EXISTING _sortGroupsBySmallest() METHOD
void _sortGroupsBySmallest() {
  // ✅ NO setState() calls during sorting!
  photoGroups.sort((a, b) => a.totalSize.compareTo(b.totalSize));
  
  // Sort photos within each group by resolution (smallest first)
  for (var group in photoGroups) {
    group.photos.sort((a, b) {
      final AssetEntity assetA = a as AssetEntity;
      final AssetEntity assetB = b as AssetEntity;
      
      final int sizeA = (assetA.width ?? 0) * (assetA.height ?? 0);
      final int sizeB = (assetB.width ?? 0) * (assetB.height ?? 0);
      return sizeA.compareTo(sizeB);
    });
  }
  
  // ✅ SINGLE setState() call at the very end
  if (mounted) {
    setState(() {
      // Just trigger rebuild - data is already sorted
    });
  }
}

// ✅ REPLACE YOUR EXISTING _sortGroupsByLargest() METHOD
void _sortGroupsByLargest() {
  // ✅ NO setState() calls during sorting!
  photoGroups.sort((a, b) => b.totalSize.compareTo(a.totalSize));
  
  // Sort photos within each group by resolution (largest first)
  for (var group in photoGroups) {
    group.photos.sort((a, b) {
      final AssetEntity assetA = a as AssetEntity;
      final AssetEntity assetB = b as AssetEntity;
      
      final int sizeA = (assetA.width ?? 0) * (assetA.height ?? 0);
      final int sizeB = (assetB.width ?? 0) * (assetB.height ?? 0);
      return sizeB.compareTo(sizeA);
    });
  }
  
  // ✅ SINGLE setState() call at the very end
  if (mounted) {
    setState(() {
      // Just trigger rebuild - data is already sorted
    });
  }
}

// ✅ REPLACE YOUR EXISTING _sortGroupsByNewest() METHOD
// ✅ REPLACE YOUR EXISTING _sortGroupsByNewest() METHOD
void _sortGroupsByNewest() {
  // ✅ NO setState() calls during sorting!
  photoGroups.sort((a, b) {
    final dateA = a.photos.first.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
    final dateB = b.photos.first.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
    return dateB.compareTo(dateA);
  });
  
  // Sort photos within each group by date (newest first)
  for (var group in photoGroups) {
    group.photos.sort((a, b) {
      final AssetEntity assetA = a as AssetEntity;
      final AssetEntity assetB = b as AssetEntity;
      
      final dateA = assetA.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = assetB.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA);
    });
  }
  
  // ✅ SINGLE setState() call at the very end
  if (mounted) {
    setState(() {
      // Just trigger rebuild - data is already sorted
    });
  }
}

// ✅ REPLACE YOUR EXISTING _sortGroupsByOldest() METHOD
// ✅ REPLACE YOUR EXISTING _sortGroupsByOldest() METHOD
void _sortGroupsByOldest() {
  // ✅ NO setState() calls during sorting!
  photoGroups.sort((a, b) {
    final dateA = a.photos.first.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
    final dateB = b.photos.first.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
    return dateA.compareTo(dateB);
  });
  
  // Sort photos within each group by date (oldest first)
  for (var group in photoGroups) {
    group.photos.sort((a, b) {
      final AssetEntity assetA = a as AssetEntity;
      final AssetEntity assetB = b as AssetEntity;
      
      final dateA = assetA.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = assetB.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateA.compareTo(dateB);
    });
  }
  
  // ✅ SINGLE setState() call at the very end
  if (mounted) {
    setState(() {
      // Just trigger rebuild - data is already sorted
    });
  }
}

  Future<double> _getGroupSize(SimilarPhotoGroup group) async {
    double totalSize = 0.0;
    
    for (int i = 0; i < group.photos.length; i++) {
      totalSize += await _getPhotoSize(group, i);
    }
    
    return totalSize;
  }

  String _formatFileSize(double sizeInMB) {
    if (sizeInMB < 0.1) {
      return '${(sizeInMB * 1024).toStringAsFixed(1)}KB';
    } else if (sizeInMB < 1000) {
      return '${sizeInMB.toStringAsFixed(1)}MB';
    } else {
      return '${(sizeInMB / 1024).toStringAsFixed(1)}GB';
    }
  }

 Future<void> _deleteSelectedPhotos() async {
  if (!await _checkDeletePermission()) return;

  // Collect all selected photos first
  List<AssetEntity> photosToDelete = [];
  for (var group in photoGroups) {
    for (int index in group.selectedIndices) {
      photosToDelete.add(group.photos[index]);
    }
  }

  if (photosToDelete.isEmpty) return;

  // Show loading dialog
  if (mounted) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Deleting ${photosToDelete.length} photos...'),
          ],
        ),
      ),
    );
  }

  try {
    print('🗑️ Attempting to delete ${photosToDelete.length} photos');

    // ✅ FIXED: Use batch deletion with all photo IDs at once
    List<String> photoIds = photosToDelete.map((photo) => photo.id).toList();
    
    // This will show only ONE permission dialog for all photos
    List<String> successfullyDeleted = await PhotoManager.editor.deleteWithIds(photoIds);
    
    // Calculate results
    int deletedCount = successfullyDeleted.length;
    int failedCount = photosToDelete.length - deletedCount;

    // Close loading dialog
    if (mounted) {
      Navigator.of(context).pop();
    }

    if (failedCount == 0) {
      // All photos deleted successfully
      print('✅ Successfully deleted $deletedCount photos');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully deleted $deletedCount photos'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.of(context).pop(true); // Return success
      }
      
    } else {
      // Some photos failed to delete
      print('⚠️ Deleted $deletedCount photos, $failedCount failed');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted $deletedCount photos. $failedCount failed.'),
            backgroundColor: Colors.orange,
          ),
        );
        
        Navigator.of(context).pop(deletedCount > 0); // Return true if any deleted
      }
    }

  } catch (e) {
    print('❌ Error deleting photos: $e');
    
    if (mounted) {
      Navigator.of(context).pop(); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting photos: $e'),
          backgroundColor: Colors.red,
        ),
      );
      
      Navigator.of(context).pop(false);
    }
  }
}


  void _removeDeletedPhotosFromUI(List<String> failedIds, List<AssetEntity> photosToDelete) {
    // Simple approach: navigate back to home screen
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      
      if (failedIds.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${photosToDelete.length - failedIds.length} photos deleted successfully. ${failedIds.length} failed to delete.'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('All ${photosToDelete.length} photos deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<bool> _checkDeletePermission() async {
    final PermissionState permission = await PhotoManager.requestPermissionExtend();
    
    if (permission != PermissionState.authorized && permission != PermissionState.limited) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission denied. Cannot delete photos.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
    return true;
  }

  void _cleanSelectedPhotos() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clean Photos'),
        content: Text(
          'Are you sure you want to delete $selectedCount selected photos? '
          'This will free up ${selectedSize.toStringAsFixed(1)}MB of storage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              _deleteSelectedPhotos(); // This calls your actual deletion method
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.blue, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Similar',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
       // ✅ FIXED: Correct logic
actions: [
  Flexible( // ✅ Wrap with Flexible
    child: TextButton(
      onPressed: _isSelectingAll 
          ? null 
          : (selectedCount == _getTotalSelectablePhotos() ? _deselectAll : _selectAll),
      child: Text(
        selectedCount == _getTotalSelectablePhotos() ? 'Deselect all' : 'Select all',
        style: const TextStyle(
          color: Colors.blue,
          fontSize: 13, // ✅ Reduced from 14 to 13
        ),
        overflow: TextOverflow.ellipsis, // ✅ Add this
      ),
    ),
  ),
],
      ),
      body: isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading photo groups...'), // Updated text
                ],
              ),
            )
          : Column(
              children: [
                // Header info
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Sort button (replaces "Photos Grouped")
                      GestureDetector(
                        onTap: _showSortOptions,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blue),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.sort, color: Colors.blue, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                _currentSortOption.displayName,
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Photo groups
                Expanded(
                  child: photoGroups.isEmpty
                      ? const Center(
                          child: Text(
                            'No similar photos found to group',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : ListView.builder(
  itemCount: photoGroups.length,
  // ✅ PERFORMANCE OPTIMIZATIONS
  cacheExtent: 1000.0, // Cache more items to reduce rebuilds
  addAutomaticKeepAlives: true, // Keep items alive when scrolling
  addRepaintBoundaries: true, // Reduce repaints
  physics: const BouncingScrollPhysics(), // Smoother scrolling
  itemBuilder: (context, index) {
    return _buildPhotoGroup(index); // ✅ ADD THIS LINE
  },
),

                ),
              ],
            ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }
String _formatGroupSize(double sizeInMB) {
  if (sizeInMB == 0.0) {
    return '(calculating...)'; // Show while calculating
  }
  
  if (sizeInMB < 1) {
    return '(${(sizeInMB * 1024).toStringAsFixed(0)} KB)';
  } else if (sizeInMB < 1024) {
    return '(${sizeInMB.toStringAsFixed(1)} MB)';
  } else {
    return '(${(sizeInMB / 1024).toStringAsFixed(1)} GB)';
  }
}

Widget _buildPhotoGroup(int groupIndex) {
  final group = photoGroups[groupIndex];
  
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ✅ Display group size (will show "calculating..." initially)
            Text(
              '${group.photos.length} Photos ${_formatGroupSize(group.totalSize)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            TextButton(
              onPressed: () => _deselectGroup(groupIndex),
              child: const Text(
                'Deselect all',
                style: TextStyle(color: Colors.blue, fontSize: 14),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        _buildOptimizedPhotosGrid(groupIndex),
      ],
    ),
  );
}


// ✅ Optimized grid with better performance
Widget _buildOptimizedPhotosGrid(int groupIndex) {
  final group = photoGroups[groupIndex];
  
  return GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      crossAxisSpacing: 2,
      mainAxisSpacing: 2,
    ),
    itemCount: math.min(group.photos.length, 6), // ✅ CRITICAL: Keep this limit!
    cacheExtent: 500.0,
    addAutomaticKeepAlives: false,
    addRepaintBoundaries: true,
    itemBuilder: (context, photoIndex) {
      return RepaintBoundary(
        child: GestureDetector(
          onTap: () => _togglePhotoSelection(groupIndex, photoIndex),
          child: _buildPhotoItem(groupIndex, photoIndex),
        ),
      );
    },
  );
}
  Widget _buildSimplePhotosGrid(int groupIndex) {
    final group = photoGroups[groupIndex];
    
    // Show max 6 photos per group for performance
    final photosToShow = group.photos.take(6).toList();
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: photosToShow.length,
      itemBuilder: (context, index) {
        return _buildPhotoItem(groupIndex, index);
      },
    );
  }

 Widget _buildPhotoItem(int groupIndex, int photoIndex) {
  final group = photoGroups[groupIndex];
  final photo = group.photos[photoIndex];
  final isSelected = group.selectedIndices.contains(photoIndex);
  final isBest = photoIndex == group.bestPhotoIndex;
  
  return GestureDetector(
    onTap: () => _togglePhotoSelection(groupIndex, photoIndex),
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
      ),
      child: Stack(
        children: [ // ✅ FIXED: Proper Stack children array
          // Photo thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: FutureBuilder<Uint8List?>(
 future: group.photos[photoIndex].thumbnailDataWithSize(
  const ThumbnailSize(150, 150), // ✅ SMALLER SIZE
  quality: 60, // ✅ LOWER QUALITY
),

  builder: (context, snapshot) {
    if (snapshot.hasData && snapshot.data != null) {
      return Image.memory(
  snapshot.data!,
  fit: BoxFit.cover,
  // ✅ MATCH THE THUMBNAIL SIZE
  cacheWidth: 150,
  cacheHeight: 150,
  gaplessPlayback: true,
);

    }
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  },
),
          ),
          
          // Selection indicator
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue : Colors.white.withOpacity(0.8),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.grey,
                  width: 1,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
          ),
          
          // Best indicator
          if (isBest)
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4AA),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Best',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ], // ✅ FIXED: Proper closing bracket for Stack children
      ),
    ),
  );
}


  // Update your UI to show loading when calculating sizes
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: selectedCount > 0 && !isCalculatingSize ? _cleanSelectedPhotos : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              disabledBackgroundColor: Colors.grey[300],
            ),
            child: isCalculatingSize 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  'Clean $selectedCount photos (${selectedSize.toStringAsFixed(1)}MB)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
          ),
        ),
      ),
    );
  }

   // ✅ ADD THIS METHOD AT THE END
 // ✅ FIND YOUR dispose() METHOD AND ADD THIS
@override
void dispose() {
  _debounceTimer?.cancel();
  _sizeCalculationTimer?.cancel(); // ✅ ADD THIS LINE
  super.dispose();
}

}

class SortOptionsBottomSheet extends StatefulWidget {
  final PhotoSortOption currentOption;
  final Function(PhotoSortOption) onOptionSelected;

  const SortOptionsBottomSheet({
    Key? key,
    required this.currentOption,
    required this.onOptionSelected,
  }) : super(key: key);

  @override
  State<SortOptionsBottomSheet> createState() => _SortOptionsBottomSheetState();
}

class _SortOptionsBottomSheetState extends State<SortOptionsBottomSheet> {
  late PhotoSortOption _selectedOption;

  @override
  void initState() {
    super.initState();
    // ✅ FIXED: Only initialize the selected option
    _selectedOption = widget.currentOption;
  }
  


  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Close button
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.grey),
            ),
          ),
          
          // Title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Display first',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Sort options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // First row: Newest and Oldest
                Row(
                  children: [
                    Expanded(
                      child: _buildSortOption(
                        PhotoSortOption.newest,
                        isSelected: _selectedOption == PhotoSortOption.newest,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSortOption(
                        PhotoSortOption.oldest,
                        isSelected: _selectedOption == PhotoSortOption.oldest,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Second row: Largest and Smallest
                Row(
                  children: [
                    Expanded(
                      child: _buildSortOption(
                        PhotoSortOption.largest,
                        isSelected: _selectedOption == PhotoSortOption.largest,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSortOption(
                        PhotoSortOption.smallest,
                        isSelected: _selectedOption == PhotoSortOption.smallest,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Apply button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedOption != widget.currentOption 
                    ? () {
                        widget.onOptionSelected(_selectedOption);
                        Navigator.pop(context);
                      }
                    : null, // Disabled if no change
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedOption != widget.currentOption 
                      ? Colors.blue 
                      : Colors.grey[300],
                  foregroundColor: _selectedOption != widget.currentOption 
                      ? Colors.white 
                      : Colors.grey[600],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Apply',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 34),
        ],
      ),
    );
  }
Widget _buildSortOption(PhotoSortOption option, {required bool isSelected}) {
  return GestureDetector(
    onTap: () {
      setState(() {
        _selectedOption = option;
      });
    },
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.blue : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            option.icon, // ✅ FIXED: Use option.icon instead of Icons.sort
            color: isSelected ? Colors.white : Colors.blue,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            option.displayName,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.blue,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    ),
  );
}

}
