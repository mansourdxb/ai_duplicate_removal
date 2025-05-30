import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/similar_photo_group.dart';
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

// Add this data structure to similar_photos_screen.dart as well


class SimilarPhotosScreen extends StatefulWidget {
  final List<AssetEntity> similarPhotos;
  final int totalCount;
  final double totalSize;
  final List<SimilarPhotoGroup>? preGroupedPhotos; // Add this

 const SimilarPhotosScreen({
    Key? key,
    required this.similarPhotos,
    required this.totalCount,
    required this.totalSize,
    this.preGroupedPhotos, // Add this
  }) : super(key: key);

  @override
  State<SimilarPhotosScreen> createState() => _SimilarPhotosScreenState();
}

class _SimilarPhotosScreenState extends State<SimilarPhotosScreen> {
  List<SimilarPhotoGroup> photoGroups = [];
  bool isLoading = true;
  int selectedCount = 0;
  double selectedSize = 0.0;
  int processedCount = 0;
  PhotoSortOption _currentSortOption = PhotoSortOption.newest;

  @override
void initState() {
  super.initState();
  
  // If we have pre-grouped photos, use them directly
  if (widget.preGroupedPhotos != null && widget.preGroupedPhotos!.isNotEmpty) {
    _usePreGroupedPhotos();
  } else {
    // Fallback to original grouping method
    _groupSimilarPhotos();
  }
}

void _usePreGroupedPhotos() {
  setState(() {
    photoGroups = List.from(widget.preGroupedPhotos!);
    isLoading = false;
    _calculateInitialSelection();
    _applySorting();
  });
}
  void _groupSimilarPhotos() async {
    setState(() {
      isLoading = true;
      processedCount = 0;
    });

    try {
      // Limit processing to first 500 photos for performance
      final photosToProcess = widget.similarPhotos.take(500).toList();
      
      List<PhotoData> photoDataList = [];
      
      // Process photos in batches of 20 for better performance
      const batchSize = 20;
      for (int i = 0; i < photosToProcess.length; i += batchSize) {
        final endIndex = (i + batchSize < photosToProcess.length) 
            ? i + batchSize 
            : photosToProcess.length;
        
        final batch = photosToProcess.sublist(i, endIndex);
        
        // Process batch
        for (int j = 0; j < batch.length; j++) {
          final asset = batch[j];
          try {
            final thumbnail = await asset.thumbnailDataWithSize(
              const ThumbnailSize(150, 150), // Smaller thumbnail for performance
              quality: 60, // Lower quality for performance
            );
            
            if (thumbnail != null) {
              photoDataList.add(PhotoData(
                asset: asset,
                thumbnail: thumbnail,
                index: i + j,
                size: 3.0, // Use default size to avoid file system calls
              ));
            }
          } catch (e) {
            print('Error processing photo ${i + j}: $e');
            // Continue with next photo
          }
        }
        
        // Update progress
        setState(() {
          processedCount = i + batch.length;
        });
        
        // Add small delay to prevent UI blocking
        await Future.delayed(const Duration(milliseconds: 10));
      }
      
      // Create simple groups based on date
      final groups = await _createSimpleGroups(photoDataList);
      
      setState(() {
        photoGroups = groups;
        isLoading = false;
        _calculateInitialSelection();
        setState(() {
  photoGroups = groups;
  isLoading = false;
  _calculateInitialSelection();
  _applySorting(); // ADD THIS LINE
});

      });
      
    } catch (e) {
      print('Error grouping photos: $e');
      setState(() {
        isLoading = false;
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

  Future<List<SimilarPhotoGroup>> _createSimpleGroups(List<PhotoData> photoDataList) async {
  List<SimilarPhotoGroup> groups = [];
  
  // Group by month for simplicity and performance
  Map<String, List<PhotoData>> monthGroups = {};
  
  for (var photo in photoDataList) {
    final date = photo.asset.createDateTime ?? DateTime.now();
    final monthKey = "${date.year}-${date.month.toString().padLeft(2, '0')}";
    
    if (!monthGroups.containsKey(monthKey)) {
      monthGroups[monthKey] = [];
    }
    monthGroups[monthKey]!.add(photo);
  }
  
  // Create groups from month groups
  for (var entry in monthGroups.entries) {
    if (entry.value.length >= 2) {
      // Sort by date within the group
      entry.value.sort((a, b) {
        final dateA = a.asset.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = b.asset.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });
      
      // Split large groups into smaller ones
      const maxGroupSize = 8;
      for (int i = 0; i < entry.value.length; i += maxGroupSize) {
        final endIndex = (i + maxGroupSize < entry.value.length) 
            ? i + maxGroupSize 
            : entry.value.length;
        
        final groupPhotos = entry.value.sublist(i, endIndex);
        final totalSize = groupPhotos.length * 3.0;
        
        // Find the best photo in this group
        final photoAssets = groupPhotos.map((p) => p.asset).toList();
        final bestIndex = await _findBestPhotoIndex(photoAssets); // USE THE NEW FUNCTION
        
        groups.add(SimilarPhotoGroup(
    groupId: 'group_${groups.length}', // Add this required parameter
    photos: photoAssets, // Your existing photos list
    reason: 'Similar photos detected', // Add this required parameter
    bestPhotoIndex: 0, // Add this (defaults to first photo)
    totalSize: 0.0, // Add this (you can calculate actual size later)
  ));
      }
    }
  }
  
  // Sort groups by size (largest first)
  groups.sort((a, b) => b.totalSize.compareTo(a.totalSize));
  
  // Limit to 20 groups for performance
  if (groups.length > 20) {
    groups = groups.take(20).toList();
  }
  
  return groups;
}

void _calculateInitialSelection() {
  selectedCount = 0;
  selectedSize = 0.0;
  
  for (var group in photoGroups) {
    // Simple approach: select all photos except the first one
    for (int i = 1; i < group.photos.length; i++) {
      // Add your selection logic here
      selectedCount++;
      // Calculate size if needed
    }
  }
}


  void _togglePhotoSelection(int groupIndex, int photoIndex) {
    setState(() {
      final group = photoGroups[groupIndex];
      final photoSize = group.totalSize / group.photos.length;
      
      if (group.selectedIndices.contains(photoIndex)) {
        group.selectedIndices.remove(photoIndex);
        selectedCount--;
        selectedSize -= photoSize;
      } else {
        group.selectedIndices.add(photoIndex);
        selectedCount++;
        selectedSize += photoSize;
      }
    });
  }

  void _selectAll() {
    setState(() {
      selectedCount = 0;
      selectedSize = 0.0;
      
      for (var group in photoGroups) {
        group.selectedIndices.clear();
        for (int i = 0; i < group.photos.length; i++) {
          group.selectedIndices.add(i);
          selectedCount++;
          selectedSize += (group.totalSize / group.photos.length);
        }
      }
    });
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

  void _deselectGroup(int groupIndex) {
    setState(() {
      final group = photoGroups[groupIndex];
      final photoSize = group.totalSize / group.photos.length;
      
      selectedCount -= group.selectedIndices.length;
      selectedSize -= (group.selectedIndices.length * photoSize);
      
      group.selectedIndices.clear();
    });
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
  setState(() {
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
  });
}

void _sortGroupsByNewest() {
  photoGroups.sort((a, b) {
    final dateA = a.photos.first.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
    final dateB = b.photos.first.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
    return dateB.compareTo(dateA); // Newest first
  });
  
  // Also sort photos within each group
  for (var group in photoGroups) {
    group.photos.sort((a, b) {
      final dateA = a.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = b.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA);
    });
  }
}

void _sortGroupsByOldest() {
  photoGroups.sort((a, b) {
    final dateA = a.photos.first.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
    final dateB = b.photos.first.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
    return dateA.compareTo(dateB); // Oldest first
  });
  
  // Also sort photos within each group
  for (var group in photoGroups) {
    group.photos.sort((a, b) {
      final dateA = a.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = b.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateA.compareTo(dateB);
    });
  }
}

void _sortGroupsByLargest() {
  photoGroups.sort((a, b) => b.totalSize.compareTo(a.totalSize)); // Largest first
  
  // Sort photos within each group by resolution
  for (var group in photoGroups) {
    group.photos.sort((a, b) {
      final sizeA = (a.width ?? 0) * (a.height ?? 0);
      final sizeB = (b.width ?? 0) * (b.height ?? 0);
      return sizeB.compareTo(sizeA);
    });
  }
}

void _sortGroupsBySmallest() {
  photoGroups.sort((a, b) => a.totalSize.compareTo(b.totalSize)); // Smallest first
  
  // Sort photos within each group by resolution
  for (var group in photoGroups) {
    group.photos.sort((a, b) {
      final sizeA = (a.width ?? 0) * (a.height ?? 0);
      final sizeB = (b.width ?? 0) * (b.height ?? 0);
      return sizeA.compareTo(sizeB);
    });
  }
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
        actions: [
          TextButton(
            onPressed: selectedCount == widget.totalCount ? _deselectAll : _selectAll,
            child: Text(
              selectedCount == widget.totalCount ? 'Deselect all' : 'Select all',
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Processing similar photos...'),
                  const SizedBox(height: 8),
                  Text(
                    '$processedCount / ${widget.similarPhotos.take(500).length}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  if (widget.similarPhotos.length > 500) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Showing first 500 photos for performance',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ],
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
      if (widget.similarPhotos.length > 500) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Limited view',
            style: TextStyle(
              color: Colors.orange[700],
              fontSize: 12,
            ),
          ),
        ),
      ],
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
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: photoGroups.length,
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
          // Group header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${group.photos.length} Photos ${group.totalSize.toStringAsFixed(1)}MB',
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
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Photos grid - simplified for performance
          _buildSimplePhotosGrid(groupIndex),
        ],
      ),
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
          children: [
            // Photo thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: FutureBuilder<Uint8List?>(
                future: photo.thumbnailDataWithSize(
                  const ThumbnailSize(100, 100),
                  quality: 60,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return Image.memory(
                      snapshot.data!,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    );
                  }
                  return Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.image, color: Colors.grey),
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
            onPressed: selectedCount > 0 ? _cleanSelectedPhotos : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              disabledBackgroundColor: Colors.grey[300],
            ),
            child: Text(
              'Clean $selectedCount photos',
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performCleanup();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _performCleanup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cleaning photos...'),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context);
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully cleaned $selectedCount photos'),
          backgroundColor: Colors.green,
        ),
      );
    });
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
              Icons.sort,
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

