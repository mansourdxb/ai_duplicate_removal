import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

// Same enum as DuplicatePhotosScreen
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

class ScreenshotsScreen extends StatefulWidget {
  final List<AssetEntity> screenshots;
  final int totalCount;
  final double totalSize;

  const ScreenshotsScreen({
    Key? key,
    required this.screenshots,
    required this.totalCount,
    required this.totalSize,
  }) : super(key: key);

  @override
  State<ScreenshotsScreen> createState() => _ScreenshotsScreenState();
}

class _ScreenshotsScreenState extends State<ScreenshotsScreen> {
  Set<int> selectedIndices = <int>{};
  bool isSelectMode = false;
  bool isDeleting = false;
  
  // Use same sorting system as DuplicatePhotosScreen
  PhotoSortOption _currentSortOption = PhotoSortOption.newest;
  List<AssetEntity> sortedScreenshots = [];
  
  @override
  void initState() {
    super.initState();
    sortedScreenshots = List.from(widget.screenshots);
    _applySorting();
    // Auto-select all screenshots by default
    selectedIndices = Set.from(List.generate(sortedScreenshots.length, (index) => index));
    isSelectMode = true;
  }

  // EXACT same sorting logic as DuplicatePhotosScreen
  void _applySorting() {
    print('🔄 Applying sort: ${_currentSortOption.displayName}');
    
    switch (_currentSortOption) {
      case PhotoSortOption.newest:
        _sortScreenshotsByNewest();
        break;
      case PhotoSortOption.oldest:
        _sortScreenshotsByOldest();
        break;
      case PhotoSortOption.largest:
        _sortScreenshotsByLargest();
        break;
      case PhotoSortOption.smallest:
        _sortScreenshotsBySmallest();
        break;
    }
    
    print('✅ Sorting applied: ${_currentSortOption.displayName}');
  }

  // EXACT same sorting methods as DuplicatePhotosScreen but for screenshots
  void _sortScreenshotsByNewest() {
    sortedScreenshots.sort((a, b) {
      final dateA = a.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = b.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA); // Newest first
    });
    
    if (mounted) {
      setState(() {
        // Reset selection after sorting
        selectedIndices = Set.from(List.generate(sortedScreenshots.length, (index) => index));
      });
    }
  }

  void _sortScreenshotsByOldest() {
    sortedScreenshots.sort((a, b) {
      final dateA = a.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = b.createDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateA.compareTo(dateB); // Oldest first
    });
    
    if (mounted) {
      setState(() {
        // Reset selection after sorting
        selectedIndices = Set.from(List.generate(sortedScreenshots.length, (index) => index));
      });
    }
  }

  void _sortScreenshotsByLargest() {
    sortedScreenshots.sort((a, b) {
      final sizeA = (a.width ?? 0) * (a.height ?? 0);
      final sizeB = (b.width ?? 0) * (b.height ?? 0);
      return sizeB.compareTo(sizeA); // Largest first
    });
    
    if (mounted) {
      setState(() {
        // Reset selection after sorting
        selectedIndices = Set.from(List.generate(sortedScreenshots.length, (index) => index));
      });
    }
  }

  void _sortScreenshotsBySmallest() {
    sortedScreenshots.sort((a, b) {
      final sizeA = (a.width ?? 0) * (a.height ?? 0);
      final sizeB = (b.width ?? 0) * (b.height ?? 0);
      return sizeA.compareTo(sizeB); // Smallest first
    });
    
    if (mounted) {
      setState(() {
        // Reset selection after sorting
        selectedIndices = Set.from(List.generate(sortedScreenshots.length, (index) => index));
      });
    }
  }

  // EXACT same sort options modal as DuplicatePhotosScreen
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
      selectedIndices = Set.from(List.generate(sortedScreenshots.length, (index) => index));
    });
  }

  void _deselectAll() {
    setState(() {
      selectedIndices.clear();
    });
  }

  Future<void> _deleteSelectedScreenshots() async {
    if (selectedIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No screenshots selected for deletion'),
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
          title: const Text('Delete Screenshots'),
          content: Text(
            'Are you sure you want to delete ${selectedIndices.length} screenshot${selectedIndices.length == 1 ? '' : 's'}?\n\n'
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
      // Get selected screenshots
      List<AssetEntity> screenshotsToDelete = selectedIndices
          .map((index) => sortedScreenshots[index])
          .toList();

      print('🗑️ Deleting ${screenshotsToDelete.length} screenshots...');

      // Delete screenshots
      List<String> idsToDelete = screenshotsToDelete.map((asset) => asset.id).toList();
      final List<String> result = await PhotoManager.editor.deleteWithIds(idsToDelete);

      print('✅ Deletion result: ${result.length} screenshots deleted');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.length} screenshot${result.length == 1 ? '' : 's'} deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Return true to indicate photos were deleted
        Navigator.of(context).pop(true);
      }

    } catch (e) {
      print('❌ Error deleting screenshots: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting screenshots: $e'),
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
    double avgSizePerScreenshot = widget.totalSize / widget.screenshots.length;
    return avgSizePerScreenshot * selectedIndices.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Same as DuplicatePhotosScreen
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.blue, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Screenshots',
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
              onPressed: selectedIndices.length == sortedScreenshots.length 
                  ? _deselectAll 
                  : _selectAll,
              child: Text(
                selectedIndices.length == sortedScreenshots.length 
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
          // Sort button - EXACT same as DuplicatePhotosScreen
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
                      '${selectedIndices.length} screenshot${selectedIndices.length == 1 ? '' : 's'} selected'
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

          // Screenshots grid
          Expanded(
            child: sortedScreenshots.isEmpty
                ? const Center(
                    child: Text(
                      'No screenshots found',
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
                      itemCount: sortedScreenshots.length,
                      itemBuilder: (context, index) {
                        final screenshot = sortedScreenshots[index];
                        final isSelected = selectedIndices.contains(index);

                        return GestureDetector(
                          onTap: () => _toggleSelection(index),
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
                                  // Screenshot thumbnail
                                  FutureBuilder<Uint8List?>(
                                    future: screenshot.thumbnailDataWithSize(
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

                                  // Screenshot info overlay
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
                                        '${screenshot.width}×${screenshot.height}',
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
      
      // Bottom Clean Button - EXACT same style as DuplicatePhotosScreen
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
                    onPressed: isDeleting ? null : _deleteSelectedScreenshots,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue, // Same as DuplicatePhotosScreen
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
                            'Clean ${selectedIndices.length} screenshot${selectedIndices.length == 1 ? '' : 's'} (${_calculateSelectedSize().toStringAsFixed(1)}GB)',
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
}

// EXACT same SortOptionsBottomSheet as DuplicatePhotosScreen
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
