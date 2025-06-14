import 'package:flutter/material.dart';
import 'dart:io';
import 'package:photo_manager/photo_manager.dart';
import '../models/video.dart';
import '../utils/thumbnail_cache.dart';
import 'dart:typed_data'; // Add this import at the top of your file

class DuplicateVideosScreen extends StatefulWidget {
  final List<List<Video>> duplicateGroups;
  final int totalCount;
  final String totalSize;

  const DuplicateVideosScreen({
    Key? key,
    required this.duplicateGroups,
    required this.totalCount,
    required this.totalSize,
  }) : super(key: key);

  @override
  State<DuplicateVideosScreen> createState() => _DuplicateVideosScreenState();
}

class _DuplicateVideosScreenState extends State<DuplicateVideosScreen> {
  // Track selected videos for deletion
  Map<String, Set<int>> selectedIndices = {};
  bool isDeleting = false;
  int selectedCount = 0;
  double selectedSize = 0.0;
  
  @override
  void initState() {
    super.initState();
    // Initialize selection with default values (all duplicates selected)
    _initializeSelection();
  }
  

  bool _areAllSelected() {
  // Returns true if all possible (non-best) videos are selected
  for (int groupIndex = 0; groupIndex < widget.duplicateGroups.length; groupIndex++) {
    final group = widget.duplicateGroups[groupIndex];
    final String groupId = 'group_$groupIndex';
    if (group.length <= 1) continue;
    // Should be all except the first (best)
    if (selectedIndices[groupId]?.length != group.length - 1) {
      return false;
    }
  }
  return true;
}

  void _initializeSelection() {
    // By default, select all duplicates (all videos except the first one in each group)
    for (int groupIndex = 0; groupIndex < widget.duplicateGroups.length; groupIndex++) {
      final group = widget.duplicateGroups[groupIndex];
      final String groupId = 'group_$groupIndex';
      
      if (group.length > 1) {
        // Select all videos except the first one
        selectedIndices[groupId] = {};
        
        for (int videoIndex = 1; videoIndex < group.length; videoIndex++) {
          selectedIndices[groupId]!.add(videoIndex);
        }
      }
    }
    
    // Calculate initial counts and sizes
    _updateSelectionStats();
  }
  
  void _updateSelectionStats() {
    int count = 0;
    double size = 0.0;
    
    for (int groupIndex = 0; groupIndex < widget.duplicateGroups.length; groupIndex++) {
      final group = widget.duplicateGroups[groupIndex];
      final String groupId = 'group_$groupIndex';
      
      if (selectedIndices.containsKey(groupId)) {
        for (int videoIndex in selectedIndices[groupId]!) {
          if (videoIndex < group.length) {
            count++;
            size += group[videoIndex].size / (1024 * 1024 * 1024); // Convert bytes to GB
          }
        }
      }
    }
    
    setState(() {
      selectedCount = count;
      selectedSize = size;
    });
  }
  
  void _toggleVideoSelection(String groupId, int videoIndex) {
    setState(() {
      if (!selectedIndices.containsKey(groupId)) {
        selectedIndices[groupId] = {};
      }
      
      if (selectedIndices[groupId]!.contains(videoIndex)) {
        selectedIndices[groupId]!.remove(videoIndex);
      } else {
        selectedIndices[groupId]!.add(videoIndex);
      }
      
      _updateSelectionStats();
    });
  }
  
Future<void> _deleteSelectedVideos() async {
  if (selectedCount == 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No videos selected for deletion'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }
  
  // Confirm deletion
  final bool? confirmDelete = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Duplicate Videos'),
      content: Text(
        'Are you sure you want to delete $selectedCount selected videos ($selectedSize GB)?\n\n'
        'This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('DELETE', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  
  if (confirmDelete != true) return;
  
  setState(() {
    isDeleting = true;
  });
  
  try {
    // Collect all videos to delete
    List<Video> videosToDelete = [];
    
    for (int groupIndex = 0; groupIndex < widget.duplicateGroups.length; groupIndex++) {
      final group = widget.duplicateGroups[groupIndex];
      final String groupId = 'group_$groupIndex';
      
      if (selectedIndices.containsKey(groupId)) {
        for (int videoIndex in selectedIndices[groupId]!) {
          if (videoIndex < group.length) {
            videosToDelete.add(group[videoIndex]);
          }
        }
      }
    }
    
    // Collect asset IDs for batch deletion
    List<String> assetIds = videosToDelete.map((video) => video.id).toList();
    
    // Use the correct method to delete assets
    final result = await PhotoManager.editor.deleteWithIds(assetIds);
    
    // Count successful deletions
    int deletedCount = result.whereType<bool>().where((success) => success).length;
    
    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully deleted $deletedCount videos'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Return true to indicate videos were deleted
      Navigator.pop(context, true);
    }
  } catch (e) {
    print('Error during batch deletion: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting videos: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        isDeleting = false;
      });
    }
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
      icon: const Icon(Icons.arrow_back, color: Colors.black87),
      onPressed: () => Navigator.pop(context),
    ),
    title: const Text(
      'Duplicate',
      style: TextStyle(
        color: Colors.black87,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
    ),
    centerTitle: true,
    actions: [
      TextButton(
        onPressed: () {
          setState(() {
            final allSelected = _areAllSelected();
            if (allSelected) {
              // Deselect all
              selectedIndices.clear();
            } else {
              // Select all (except best in each group)
              for (int groupIndex = 0; groupIndex < widget.duplicateGroups.length; groupIndex++) {
                final group = widget.duplicateGroups[groupIndex];
                final String groupId = 'group_$groupIndex';
                if (group.length > 1) {
                  selectedIndices[groupId] = {};
                  for (int videoIndex = 1; videoIndex < group.length; videoIndex++) {
                    selectedIndices[groupId]!.add(videoIndex);
                  }
                }
              }
            }
            _updateSelectionStats();
          });
        },
        child: Text(
          _areAllSelected() ? 'Deselect all' : 'Select all',
          style: const TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    ],
  ),
  body: isDeleting
      ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Deleting selected videos...'),
            ],
          ),
        )
      : Column(
          children: [
            // Stats bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Found ${widget.duplicateGroups.length} duplicate',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total: ${widget.totalCount} videos • ${widget.totalSize}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Selected: $selectedCount (${selectedSize.toStringAsFixed(2)} GB)',

                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Duplicate groups list
            Expanded(
              child: ListView.builder(
                itemCount: widget.duplicateGroups.length,
                padding: const EdgeInsets.all(12),
                itemBuilder: (context, index) {
                  final group = widget.duplicateGroups[index];
                  final String groupId = 'group_$index';
                  
                  if (group.length < 2) return const SizedBox.shrink();
                  
                  return _buildDuplicateGroupCard(group, groupId, index);
                },
              ),
            ),
          ],
        ),
  bottomNavigationBar: Padding(
    padding: const EdgeInsets.all(16.0),
    child: SafeArea(
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: selectedCount > 0 ? _deleteSelectedVideos : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Clean →',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    ),
  ),
);

  }
  
 Widget _buildDuplicateGroupCard(List<Video> group, String groupId, int groupIndex) {
  double groupSize = group.fold(0.0, (sum, v) => sum + v.size);
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.07),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: count, size, deselect
          Row(
            children: [
              Text(
                '${group.length} Videos',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(groupSize / 1024 / 1024).toStringAsFixed(2)} MB',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    selectedIndices[groupId]?.clear();
                    _updateSelectionStats();
                  });
                },
                child: const Text(
                  'Deselect all',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Thumbnails Row
          Row(
            children: List.generate(group.length, (i) {
              final video = group[i];
              final isSelected = selectedIndices[groupId]?.contains(i) ?? false;
              final isBest = i == 0;
              return Expanded(
                child: GestureDetector(
                  onTap: isBest
                      ? null
                      : () => _toggleVideoSelection(groupId, i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Stack(
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: FutureBuilder<Uint8List?>(
                              future: ThumbnailCache.generateAndCacheThumbnail(video.asset),
                              builder: (context, snapshot) {
                                if (snapshot.hasData && snapshot.data != null) {
                                  return Image.memory(
                                    snapshot.data!,
                                    fit: BoxFit.cover,
                                  );
                                }
                                return Container(
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: Icon(Icons.videocam, color: Colors.grey),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        // Play icon
                        Positioned.fill(
                          child: Center(
                            child: Icon(
                              Icons.play_circle_outline,
                              color: Colors.white.withOpacity(0.85),
                              size: 32,
                            ),
                          ),
                        ),
                        // Duration at top right
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _formatDuration(video.duration),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        // "Best" label on first video
                        if (isBest)
                          Positioned(
                            bottom: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Best',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        // Checkbox for selected (not on Best)
                        if (!isBest)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blue : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? Colors.blue : Colors.grey,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                isSelected ? Icons.check : Icons.check_box_outline_blank,
                                color: isSelected ? Colors.white : Colors.grey,
                                size: 20,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    ),
  );
}


  Widget _buildVideoItem(
    Video video, 
    String groupId, 
    int videoIndex, 
    {required bool isOriginal, required bool isSelected}
  ) {
    return InkWell(
      onTap: isOriginal 
          ? null 
          : () => _toggleVideoSelection(groupId, videoIndex),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: isSelected ? Colors.red.withOpacity(0.05) : Colors.transparent,
        child: Row(
          children: [
            // Thumbnail
            Stack(
              children: [
                Container(
                  width: 80,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                    border: isOriginal
                        ? Border.all(color: Colors.blue, width: 2)
                        : isSelected
                            ? Border.all(color: Colors.red, width: 2)
                            : null,
                  ),
                child: ClipRRect(
  borderRadius: BorderRadius.circular(6),
  child: FutureBuilder<Uint8List?>(
    future: ThumbnailCache.generateAndCacheThumbnail(video.asset),
    builder: (context, snapshot) {
      if (snapshot.hasData && snapshot.data != null) {
        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
        );
      }
      return const Center(
        child: Icon(Icons.videocam, color: Colors.grey),
      );
    },
  ),
),
                ),
                
                // Play icon overlay
                Positioned.fill(
                  child: Center(
                    child: Icon(
                      Icons.play_circle_outline,
                      color: Colors.white.withOpacity(0.8),
                      size: 30,
                    ),
                  ),
                ),
                
                // Duration badge
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatDuration(video.duration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(width: 12),
            
            // Video info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isOriginal)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'KEEP',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          video.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: isOriginal ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${(video.size / (1024 * 1024)).toStringAsFixed(1)} MB',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${video.width}x${video.height}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(video.dateCreated),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Selection checkbox (for duplicates only)
            if (!isOriginal)
              Checkbox(
                value: isSelected,
                onChanged: (value) => _toggleVideoSelection(groupId, videoIndex),
                activeColor: Colors.red,
              ),
          ],
        ),
      ),
    );
  }
  
  String _formatDuration(int milliseconds) {
    final int seconds = (milliseconds / 1000).round();
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
