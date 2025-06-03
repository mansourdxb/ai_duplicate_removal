import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

// Using the same enum as in your ScreenshotsScreen
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

class BlurryPhotosScreen extends StatefulWidget {
  final List<AssetEntity> blurryPhotos;
  final int totalCount;
  final double totalSize;

  const BlurryPhotosScreen({
    Key? key,
    required this.blurryPhotos,
    required this.totalCount,
    required this.totalSize,
  }) : super(key: key);

  @override
  State<BlurryPhotosScreen> createState() => _BlurryPhotosScreenState();
}

class _BlurryPhotosScreenState extends State<BlurryPhotosScreen> {
  Set<int> selectedIndices = <int>{};
  bool isSelectMode = false;
  bool isDeleting = false;
  
  // Same sorting system as ScreenshotsScreen
  PhotoSortOption _currentSortOption = PhotoSortOption.newest;
  List<AssetEntity> sortedBlurryPhotos = [];
  
  @override
  void initState() {
    super.initState();
    sortedBlurryPhotos = List.from(widget.blurryPhotos);
    _applySorting();
    // Auto-select all blurry photos by default
    selectedIndices = Set.from(List.generate(sortedBlurryPhotos.length, (index) => index));
    isSelectMode = true;
  }

  void _applySorting() {
    print('🔄 Applying sort: ${_currentSortOption.displayName}');
    
    switch (_currentSortOption) {
      case PhotoSortOption.newest:
        _sortPhotosByNewest();
        break;
      case PhotoSortOption.oldest:
        _sortPhotosByOldest();
        break;
      case PhotoSortOption.largest:
        _sortPhotosByLargest();
        break;
      case PhotoSortOption.smallest:
        _sortPhotosBySmallest();
        break;
    }
    
    print('✅ Sorting applied: ${_currentSortOption.displayName}');
  }

  void _sortPhotosByNewest() {
    sortedBlurryPhotos.sort((a, b) {
      final dateA = a.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = b.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA); // Newest first
    });
    
    if (mounted) {
      setState(() {
        // Reset selection after sorting
        selectedIndices = Set.from(List.generate(sortedBlurryPhotos.length, (index) => index));
      });
    }
  }

  void _sortPhotosByOldest() {
    sortedBlurryPhotos.sort((a, b) {
      final dateA = a.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = b.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateA.compareTo(dateB); // Oldest first
    });
    
    if (mounted) {
      setState(() {
        // Reset selection after sorting
        selectedIndices = Set.from(List.generate(sortedBlurryPhotos.length, (index) => index));
      });
    }
  }

  void _sortPhotosByLargest() {
    sortedBlurryPhotos.sort((a, b) {
      final sizeA = (a.width ?? 0) * (a.height ?? 0);
      final sizeB = (b.width ?? 0) * (b.height ?? 0);
      return sizeB.compareTo(sizeA); // Largest first
    });
    
    if (mounted) {
      setState(() {
        // Reset selection after sorting
        selectedIndices = Set.from(List.generate(sortedBlurryPhotos.length, (index) => index));
      });
    }
  }

  void _sortPhotosBySmallest() {
    sortedBlurryPhotos.sort((a, b) {
      final sizeA = (a.width ?? 0) * (a.height ?? 0);
      final sizeB = (b.width ?? 0) * (b.height ?? 0);
      return sizeA.compareTo(sizeB); // Smallest first
    });
    
    if (mounted) {
      setState(() {
        // Reset selection after sorting
        selectedIndices = Set.from(List.generate(sortedBlurryPhotos.length, (index) => index));
      });
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

  void _toggleSelection(int index) {
    setState(() {
      if (selectedIndices.contains(index)) {
        selectedIndices.remove(index);
      } else {
        selectedIndices.add(index);
      }
    });
  }

  void _selectAll() {
    setState(() {
      selectedIndices = Set.from(List.generate(sortedBlurryPhotos.length, (index) => index));
    });
  }

  void _deselectAll() {
    setState(() {
      selectedIndices.clear();
    });
  }

  Future<void> _deleteSelectedPhotos() async {
    if (selectedIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No blurry photos selected for deletion'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show confirmation dialog
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Blurry Photos'),
          content: Text(
            'Are you sure you want to delete ${selectedIndices.length} blurry photo${selectedIndices.length == 1 ? '' : 's'}?\n\n'
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      isDeleting = true;
    });

    try {
      // Get selected photos
      List<AssetEntity> photosToDelete = selectedIndices
          .map((index) => sortedBlurryPhotos[index])
          .toList();

      print('🗑️ Deleting ${photosToDelete.length} blurry photos...');

      // Delete photos
      List<String> idsToDelete = photosToDelete.map((asset) => asset.id).toList();
      final List<String> result = await PhotoManager.editor.deleteWithIds(idsToDelete);

      print('✅ Deletion result: ${result.length} photos deleted');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.length} blurry photo${result.length == 1 ? '' : 's'} deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Remove deleted photos from the list
        setState(() {
          // Create a list of indices to remove (in descending order to avoid index shifting issues)
          List<int> indicesToRemove = selectedIndices.toList()..sort((a, b) => b.compareTo(a));
          
          for (int index in indicesToRemove) {
            if (index < sortedBlurryPhotos.length) {
              sortedBlurryPhotos.removeAt(index);
            }
          }
          
          // Clear selection
          selectedIndices.clear();
          
          // If all photos are deleted, return to previous screen
          if (sortedBlurryPhotos.isEmpty) {
            Navigator.of(context).pop(true);
          }
        });
      }

    } catch (e) {
      print('❌ Error deleting blurry photos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting photos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isDeleting = false;
        });
      }
    }
  }

  double _calculateSelectedSize() {
    if (selectedIndices.isEmpty) return 0.0;
    
    // Estimate size proportionally
    double avgSizePerPhoto = widget.totalSize / widget.blurryPhotos.length;
    return avgSizePerPhoto * selectedIndices.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Same as ScreenshotsScreen
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.blue, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Blurry Photos',
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
              onPressed: selectedIndices.length == sortedBlurryPhotos.length 
                  ? _deselectAll 
                  : _selectAll,
              child: Text(
                selectedIndices.length == sortedBlurryPhotos.length 
                    ? 'Deselect all' 
                    : 'Select all',
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
      body: Column(
        children: [
          // Sort button
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

          // Selection info bar
          if (isSelectMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.blue[50],
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${selectedIndices.length} blurry photo${selectedIndices.length == 1 ? '' : 's'} selected'
                      '${selectedIndices.isNotEmpty ? ' • ${_calculateSelectedSize().toStringAsFixed(1)}GB' : ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Blurry photos grid
          Expanded(
            child: sortedBlurryPhotos.isEmpty
                ? const Center(
                    child: Text(
                      'No blurry photos found',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                        childAspectRatio: 1,
                      ),
                      itemCount: sortedBlurryPhotos.length,
                      itemBuilder: (context, index) {
                        final photo = sortedBlurryPhotos[index];
                        final isSelected = selectedIndices.contains(index);

                        return GestureDetector(
                          onTap: () => _toggleSelection(index),
                          onLongPress: () {
                            // Navigate to detail view if needed
                            _openPhotoDetails(photo, index);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isSelected ? Colors.blue : Colors.transparent,
                                width: 3,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Stack(
                                children: [
                                  // Photo thumbnail
                                  FutureBuilder<Uint8List?>(
                                    future: photo.thumbnailDataWithSize(
                                      const ThumbnailSize(300, 300),
                                    ),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData && snapshot.data != null) {
                                        return Image.memory(
                                          snapshot.data!,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                        );
                                      }
                                      return Container(
                                        color: Colors.grey[300],
                                        child: const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    },
                                  ),

                                  // Selection overlay
                                  if (isSelected)
                                    Container(
                                      color: Colors.blue.withOpacity(0.3),
                                      child: const Center(
                                        child: Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                          size: 30,
                                        ),
                                      ),
                                    ),

                                  // Photo info overlay
                                  Positioned(
                                    bottom: 4,
                                    left: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _formatDate(photo.createDateTime),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      
      // Bottom Clean Button
      bottomNavigationBar: selectedIndices.isNotEmpty
          ? Container(
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
                    onPressed: isDeleting ? null : _deleteSelectedPhotos,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: isDeleting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Clean ${selectedIndices.length} blurry photo${selectedIndices.length == 1 ? '' : 's'} (${_calculateSelectedSize().toStringAsFixed(1)}GB)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
  
  // Helper method to format date without using intl package
  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return '';
    
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }
  
  void _openPhotoDetails(AssetEntity photo, int index) {
    // Navigate to detail view if needed
    // Implementation would go here
  }
}

// Same SortOptionsBottomSheet as in ScreenshotsScreen
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
