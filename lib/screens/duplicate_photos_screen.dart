import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/similar_photo_group.dart';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/similar_photo_group.dart';
import 'dart:async';

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

class DuplicatePhotosScreen extends StatefulWidget {
  final List<SimilarPhotoGroup> preGroupedPhotos; // ✅ Keep this name
  final int totalCount;
  final double totalSize;

  const DuplicatePhotosScreen({
    Key? key,
    required this.preGroupedPhotos, // ✅ Keep this name
    required this.totalCount,
    required this.totalSize,
  }) : super(key: key);

  @override
  _DuplicatePhotosScreenState createState() => _DuplicatePhotosScreenState();
}

class _DuplicatePhotosScreenState extends State<DuplicatePhotosScreen> {
  List<SimilarPhotoGroup> photoGroups = [];
  bool isLoading = true;
  int selectedCount = 0;
  double selectedSize = 0.0;
  PhotoSortOption _currentSortOption = PhotoSortOption.newest;
  bool isCalculatingSize = false;
  bool _isSelectingAll = false;
  Timer? _debounceTimer;
  Timer? _sizeCalculationTimer;
  final Map<String, double> _photoSizeCache = {};

  void _debouncedSetState(VoidCallback fn) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 16), () {
      if (mounted) {
        setState(fn);
      }
    });
  }

  Future<void> _debugDuplicatePhotosScreen() async {
    print('=== DUPLICATE PHOTOS SCREEN DEBUG ===');
    print('📊 Pre-grouped photos provided: ${widget.preGroupedPhotos.length} groups');
    print('📊 Total count parameter: ${widget.totalCount}');
    print('📊 Total size parameter: ${widget.totalSize}MB');
    
    if (widget.preGroupedPhotos.isNotEmpty) {
      int totalPhotosInPreGroups = 0;
      for (var group in widget.preGroupedPhotos) {
        totalPhotosInPreGroups += group.photos.length;
      }
      print('📊 Total photos in pre-groups: $totalPhotosInPreGroups');
      print('✅ Using pre-grouped photos - NO RE-ANALYSIS NEEDED');
    } else {
      print('❌ ERROR: No pre-grouped photos available');
    }
    print('=== END DUPLICATE PHOTOS SCREEN DEBUG ===\n');
  }

  Future<void> _calculateGroupSizes() async {
    print('🔄 Calculating group sizes...');
    
    for (int i = 0; i < photoGroups.length; i++) {
      final group = photoGroups[i];
      double totalSize = 0.0;
      
      for (var photo in group.photos) {
        totalSize += await _getPhotoSizeFromAsset(photo);
      }
      
      group.totalSize = totalSize;
      
      if (mounted) {
        setState(() {});
      }
      
      await Future.delayed(const Duration(milliseconds: 5));
    }
    
    print('✅ Group sizes calculated');
  }

  @override
  void initState() {
    super.initState();
    _debugDuplicatePhotosScreen();
    
    if (widget.preGroupedPhotos.isNotEmpty) {
      print('✅ Using pre-grouped duplicate photos from Home screen');
      _usePreGroupedPhotos();
    } else {
      print('❌ CRITICAL ERROR: No pre-grouped duplicate photos provided!');
      _showErrorAndReturn();
    }
  }

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
            'No duplicate photo groups available. Please go back to the home screen and try again.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
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
    
    _calculateGroupSizes();
    _calculateInitialSelectionOptimized();
    _applySorting();
    
    print('✅ Pre-grouped duplicate photos loaded instantly');
  }

  void _calculateInitialSelectionOptimized() async {
    print('🔄 _calculateInitialSelection() called');
    
    int tempCount = 0;
    
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
      selectedSize = 0.0;
    });
    
    _calculateInitialSizes();
    
    print('📊 Initial selection: $tempCount photos selected');
  }

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
    
    if (mounted) {
      setState(() {
        selectedSize = tempSize;
      });
    }
  }

  Future<int> _findBestPhotoIndex(List<AssetEntity> photos) async {
    if (photos.length <= 1) return 0;
    
    int bestIndex = 0;
    double bestScore = 0;
    
    for (int i = 0; i < photos.length; i++) {
      double score = 0;
      final photo = photos[i];
      
      final width = photo.width ?? 0;
      final height = photo.height ?? 0;
      final totalPixels = width * height;
      score += totalPixels / 100000.0;
      
      if (width > 0 && height > 0) {
        final aspectRatio = width / height;
        if (aspectRatio >= 0.7 && aspectRatio <= 1.5) {
          score += 50;
        }
        if (aspectRatio < 0.3 || aspectRatio > 3.0) {
          score -= 30;
        }
      }
      
      try {
        final file = await photo.file;
        if (file != null) {
          final sizeInBytes = await file.length();
          final sizeInMB = sizeInBytes / (1024 * 1024);
          
          if (sizeInMB >= 2 && sizeInMB <= 8) {
            score += 30;
          } else if (sizeInMB > 8) {
            score += 20;
          } else if (sizeInMB < 0.5) {
            score -= 20;
          }
        }
      } catch (e) {
        // No penalty
      }
      
      final date = photo.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final hoursSinceEpoch = date.millisecondsSinceEpoch / (1000 * 60 * 60);
      score += hoursSinceEpoch * 0.0001;
      
      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }
    
    return bestIndex;
  }

  Future<double> _getPhotoSizeFromAsset(AssetEntity asset) async {
    if (_photoSizeCache.containsKey(asset.id)) {
      return _photoSizeCache[asset.id]!;
    }
    
    try {
      final file = await asset.file;
      if (file != null && await file.exists()) {
        final sizeInBytes = await file.length();
        final sizeInMB = sizeInBytes / (1024 * 1024);
        
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
        return sizeInBytes / (1024 * 1024);
      } else {
        print('⚠️ Photo ${photo.id} no longer exists - was deleted');
        return 0.0;
      }
    } catch (e) {
      print('⚠️ Photo no longer accessible: $e');
      return 0.0;
    }
  }

  void _togglePhotoSelection(int groupIndex, int photoIndex) {
    final group = photoGroups[groupIndex];
    
    bool wasSelected = group.selectedIndices.contains(photoIndex);
    int countChange = 0;
    
    if (wasSelected) {
      group.selectedIndices.remove(photoIndex);
      countChange = -1;
    } else {
      if (photoIndex != group.bestPhotoIndex) {
        group.selectedIndices.add(photoIndex);
        countChange = 1;
      }
    }
    
    if (countChange != 0) {
      setState(() {
        selectedCount += countChange;
      });
      
      _updateSizeInBackgroundSilent();
    }
  }

  void _updateSizeInBackgroundSilent() async {
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
      
      if (mounted) {
        setState(() {
          selectedSize = tempSize;
        });
      }
    });
  }

  void _updateSizeForPhotoSafe(AssetEntity photo, bool isSelected) async {
    try {
      final size = await _getPhotoSizeFromAsset(photo);
      
      if (mounted) {
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

  Future<void> _selectAll() async {
    if (_isSelectingAll) return;
    
    setState(() {
      _isSelectingAll = true;
    });
    
    try {
      int tempSelectedCount = 0;
      
      List<SimilarPhotoGroup> groupsSnapshot = List.from(photoGroups);
      
      for (var group in groupsSnapshot) {
        group.selectedIndices.clear();
        
        for (int i = 0; i < group.photos.length; i++) {
          if (i != group.bestPhotoIndex) {
            group.selectedIndices.add(i);
            tempSelectedCount++;
          }
        }
      }
      
      setState(() {
        selectedCount = tempSelectedCount;
        selectedSize = 0.0;
      });
      
      _calculateSizesInBackgroundSilent();
      
    } finally {
      setState(() {
        _isSelectingAll = false;
      });
    }
  }

  void _calculateSizesInBackgroundSilent() async {
    double tempSize = 0.0;
    
    for (var group in photoGroups) {
      for (int index in Set.from(group.selectedIndices)) {
        tempSize += await _getPhotoSizeFromAsset(group.photos[index]);
      }
    }
    
    if (mounted) {
      setState(() {
        selectedSize = tempSize;
      });
    }
  }

  int _getTotalSelectablePhotos() {
    int total = 0;
    for (var group in photoGroups) {
      total += group.photos.length - 1;
    }
    return total;
  }

  int _getTotalPhotos() {
    int total = 0;
    for (var group in photoGroups) {
      total += group.photos.length;
    }
    return total;
  }

  void _calculateSizesInBackground() async {
    double tempSize = 0.0;
    int processedPhotos = 0;
    int totalPhotos = selectedCount;
    
    for (var group in photoGroups) {
      for (int index in Set.from(group.selectedIndices)) {
        tempSize += await _getPhotoSizeFromAsset(group.photos[index]);
        processedPhotos++;
        
        if (processedPhotos % 20 == 0 || processedPhotos == totalPhotos) {
          _debouncedSetState(() {
            selectedSize = tempSize;
          });
        }
      }
    }
    
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
    
    _recalculateSelectionOptimized();
  }

  void _deselectAll() {
    setState(() {
      selectedCount = 0;
      selectedSize = 0.0;
      
      for (var group in photoGroups) {
        group.selectedIndices.clear();
      }
    });
  }

  void _recalculateSelectionOptimized() async {
    double tempSize = 0.0;
    
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

  Future<void> _performSafeSetOperation(Function operation) async {
    try {
      await operation();
    } catch (e) {
      if (e.toString().contains('Concurrent modification')) {
        print('⚠️ Concurrent modification detected, retrying...');
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
          setState(() {
            _currentSortOption = option;
          });
          _applySorting();
        },
      ),
    );
  }

  void _applySorting() {
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

  void _sortGroupsBySmallest() {
    photoGroups.sort((a, b) => a.totalSize.compareTo(b.totalSize));
    
    for (var group in photoGroups) {
      group.photos.sort((a, b) {
        final AssetEntity assetA = a as AssetEntity;
        final AssetEntity assetB = b as AssetEntity;
        
        final int sizeA = (assetA.width ?? 0) * (assetA.height ?? 0);
        final int sizeB = (assetB.width ?? 0) * (assetB.height ?? 0);
        return sizeA.compareTo(sizeB);
      });
    }
    
    if (mounted) {
      setState(() {});
    }
  }

  void _sortGroupsByLargest() {
    photoGroups.sort((a, b) => b.totalSize.compareTo(a.totalSize));
    
    for (var group in photoGroups) {
      group.photos.sort((a, b) {
        final AssetEntity assetA = a as AssetEntity;
        final AssetEntity assetB = b as AssetEntity;
        
        final int sizeA = (assetA.width ?? 0) * (assetA.height ?? 0);
        final int sizeB = (assetB.width ?? 0) * (assetB.height ?? 0);
        return sizeB.compareTo(sizeA);
      });
    }
    
    if (mounted) {
      setState(() {});
    }
  }

  void _sortGroupsByNewest() {
    photoGroups.sort((a, b) {
      final dateA = a.photos.first.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = b.photos.first.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA);
    });
    
    for (var group in photoGroups) {
      group.photos.sort((a, b) {
        final AssetEntity assetA = a as AssetEntity;
        final AssetEntity assetB = b as AssetEntity;
        
        final dateA = assetA.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = assetB.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });
    }
    
    if (mounted) {
      setState(() {});
    }
  }

  void _sortGroupsByOldest() {
    photoGroups.sort((a, b) {
      final dateA = a.photos.first.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = b.photos.first.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateA.compareTo(dateB);
    });
    
    for (var group in photoGroups) {
      group.photos.sort((a, b) {
        final AssetEntity assetA = a as AssetEntity;
        final AssetEntity assetB = b as AssetEntity;
        
        final dateA = assetA.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = assetB.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateA.compareTo(dateB);
      });
    }
    
    if (mounted) {
      setState(() {});
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

    List<AssetEntity> photosToDelete = [];
    for (var group in photoGroups) {
      for (int index in group.selectedIndices) {
        photosToDelete.add(group.photos[index]);
      }
    }

    if (photosToDelete.isEmpty) return;

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

      List<String> photoIds = photosToDelete.map((photo) => photo.id).toList();
      
      List<String> successfullyDeleted = await PhotoManager.editor.deleteWithIds(photoIds);
      
      int deletedCount = successfullyDeleted.length;
      int failedCount = photosToDelete.length - deletedCount;

      if (mounted) {
        Navigator.of(context).pop();
      }

      if (failedCount == 0) {
        print('✅ Successfully deleted $deletedCount photos');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully deleted $deletedCount photos'),
              backgroundColor: Colors.green,
            ),
          );
          
          Navigator.of(context).pop(true);
        }
        
      } else {
        print('⚠️ Deleted $deletedCount photos, $failedCount failed');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted $deletedCount photos. $failedCount failed.'),
              backgroundColor: Colors.orange,
            ),
          );
          
          Navigator.of(context).pop(deletedCount > 0);
        }
      }

    } catch (e) {
      print('❌ Error deleting photos: $e');
      
      if (mounted) {
        Navigator.of(context).pop();
        
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
              Navigator.of(context).pop();
              _deleteSelectedPhotos();
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
          'Duplicates', // ✅ CHANGED: From 'Similar' to 'Duplicates'
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          Flexible(
            child: TextButton(
              onPressed: _isSelectingAll 
                  ? null 
                  : (selectedCount == _getTotalSelectablePhotos() ? _deselectAll : _selectAll),
              child: Text(
                selectedCount == _getTotalSelectablePhotos() ? 'Deselect all' : 'Select all',
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
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
                  Text('Loading duplicate photo groups...'), // ✅ CHANGED: Updated text
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
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
                              const SizedBox(width: 8),
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
                
                Expanded(
                  child: photoGroups.isEmpty
                      ? const Center(
                          child: Text(
                            'No duplicate photos found to group', // ✅ CHANGED: Updated text
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: photoGroups.length,
                          cacheExtent: 1000.0,
                          addAutomaticKeepAlives: true,
                          addRepaintBoundaries: true,
                          physics: const BouncingScrollPhysics(),
                          itemBuilder: (context, index) {
                            return _buildPhotoGroup(index);
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
      return '(calculating...)';
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
      itemCount: math.min(group.photos.length, 6),
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
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: FutureBuilder<Uint8List?>(
                future: group.photos[photoIndex].thumbnailDataWithSize(
                  const ThumbnailSize(150, 150),
                  quality: 60,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return Image.memory(
                      snapshot.data!,
                      fit: BoxFit.cover,
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
          ],
        ),
      ),
    );
  }

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

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _sizeCalculationTimer?.cancel();
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
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.grey),
            ),
          ),
          
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
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
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
                    : null,
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
              option.icon,
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
