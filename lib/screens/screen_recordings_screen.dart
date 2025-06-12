import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:typed_data';

class ScreenRecordingsScreen extends StatefulWidget {
  final List<AssetEntity> screenRecordings;
  final int totalCount;
  final double totalSize;

  const ScreenRecordingsScreen({
    Key? key,
    required this.screenRecordings,
    required this.totalCount,
    required this.totalSize,
  }) : super(key: key);

  @override
  State<ScreenRecordingsScreen> createState() => _ScreenRecordingsScreenState();
}

class _ScreenRecordingsScreenState extends State<ScreenRecordingsScreen> {
  List<AssetEntity> screenRecordings = [];
  Set<AssetEntity> selectedRecordings = {};
  bool isDeleting = false;

  @override
  void initState() {
    super.initState();
    screenRecordings = widget.screenRecordings;
  }

  void _toggleSelection(AssetEntity recording) {
    setState(() {
      if (selectedRecordings.contains(recording)) {
        selectedRecordings.remove(recording);
      } else {
        selectedRecordings.add(recording);
      }
    });
  }

  void _selectAll() {
    setState(() {
      selectedRecordings = Set.from(screenRecordings);
    });
  }

  void _deselectAll() {
    setState(() {
      selectedRecordings.clear();
    });
  }

  Future<void> _deleteSelected() async {
    if (selectedRecordings.isEmpty) return;
    
    setState(() {
      isDeleting = true;
    });
    
    try {
      // Delete selected recordings
      final result = await PhotoManager.editor.deleteWithIds(
        selectedRecordings.map((e) => e.id).toList(),
      );
      
      if (result.isNotEmpty) {
        // Update the list
        setState(() {
          screenRecordings.removeWhere((recording) => selectedRecordings.contains(recording));
          selectedRecordings.clear();
        });
        
        Navigator.pop(context, true); // Return true to indicate deletion
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete some recordings'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error deleting recordings: $e');
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
          'Screen Recordings',
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
          if (!isDeleting && screenRecordings.isNotEmpty)
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
                    'Deleting ${selectedRecordings.length} recordings...',
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
                                '${selectedRecordings.length} Selected',
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
                          onPressed: selectedRecordings.isNotEmpty ? _deleteSelected : null,
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
                  child: screenRecordings.isEmpty
                      ? const Center(
                          child: Text('No screen recordings found'),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: screenRecordings.length,
                          itemBuilder: (context, index) {
                            final recording = screenRecordings[index];
                            final isSelected = selectedRecordings.contains(recording);
                            return _buildRecordingItem(recording, isSelected);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildRecordingItem(AssetEntity recording, bool isSelected) {
    return GestureDetector(
      onTap: () => _toggleSelection(recording),
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
              ? Border.all(color: Colors.blue, width: 2)
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
                      future: recording.thumbnailData,
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
                      size: 40,
                    ),
                  ),
                  // Duration indicator
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${recording.duration}s',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
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
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recording.title ?? 'Untitled Recording',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${recording.width}x${recording.height}',
                    style: TextStyle(
                      fontSize: 12,
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
