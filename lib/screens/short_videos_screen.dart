import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:typed_data';

class ShortVideosScreen extends StatefulWidget {
  final List<AssetEntity> shortVideos;
  final int totalCount;
  final double totalSize;

  const ShortVideosScreen({
    Key? key,
    required this.shortVideos,
    required this.totalCount,
    required this.totalSize,
  }) : super(key: key);

  @override
  State<ShortVideosScreen> createState() => _ShortVideosScreenState();
}

class _ShortVideosScreenState extends State<ShortVideosScreen> {
  List<AssetEntity> shortVideos = [];
  Set<AssetEntity> selectedVideos = {};
  bool isDeleting = false;

  @override
  void initState() {
    super.initState();
    shortVideos = widget.shortVideos;
  }

  void _toggleSelection(AssetEntity video) {
    setState(() {
      if (selectedVideos.contains(video)) {
        selectedVideos.remove(video);
      } else {
        selectedVideos.add(video);
      }
    });
  }

  void _selectAll() {
    setState(() {
      selectedVideos = Set.from(shortVideos);
    });
  }

  void _deselectAll() {
    setState(() {
      selectedVideos.clear();
    });
  }

  Future<void> _deleteSelected() async {
    if (selectedVideos.isEmpty) return;
    
    setState(() {
      isDeleting = true;
    });
    
    try {
      // Delete selected videos
      final result = await PhotoManager.editor.deleteWithIds(
        selectedVideos.map((e) => e.id).toList(),
      );
      
      if (result.isNotEmpty) {
        // Update the list
        setState(() {
          shortVideos.removeWhere((video) => selectedVideos.contains(video));
          selectedVideos.clear();
        });
        
        Navigator.pop(context, true); // Return true to indicate deletion
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete some videos'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error deleting videos: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isDeleting = false;
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
        title: const Text(
          'Short Videos',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        centerTitle: true,
        actions: [
          if (!isDeleting && shortVideos.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'selectAll') {
                  _selectAll();
                } else if (value == 'deselectAll') {
                  _deselectAll();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'selectAll',
                  child: Text('Select All'),
                ),
                const PopupMenuItem(
                  value: 'deselectAll',
                  child: Text('Deselect All'),
                ),
              ],
            ),
        ],
      ),
      body: isDeleting
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Deleting ${selectedVideos.length} videos...',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
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
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${selectedVideos.length} Selected',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Total: ${widget.totalSize.toStringAsFixed(2)} GB',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: selectedVideos.isNotEmpty ? _deleteSelected : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: shortVideos.isEmpty
                      ? const Center(
                          child: Text('No short videos found'),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.7,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: shortVideos.length,
                          itemBuilder: (context, index) {
                            final video = shortVideos[index];
                            final isSelected = selectedVideos.contains(video);
                            return _buildVideoItem(video, isSelected);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildVideoItem(AssetEntity video, bool isSelected) {
    return GestureDetector(
      onTap: () => _toggleSelection(video),
      child: Container(
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
          border: isSelected
              ? Border.all(color: Colors.green, width: 2)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: FutureBuilder<Uint8List?>(
                      future: video.thumbnailData,
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
                  // Play icon overlay
                  Center(
                    child: Icon(
                      Icons.play_circle_outline,
                      color: Colors.white.withOpacity(0.8),
                      size: 32,
                    ),
                  ),
                  // Duration indicator
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${video.duration}s',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Selection indicator
                  if (isSelected)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title ?? 'Untitled Video',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${video.width}x${video.height}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

