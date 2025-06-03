import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:typed_data';

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
  Set<String> selectedPhotoIds = {};
  bool isDeleting = false;

  @override
  void initState() {
    super.initState();
    // Select all photos by default
    selectedPhotoIds = widget.blurryPhotos.map((photo) => photo.id).toSet();
  }

  Future<void> _deleteSelectedPhotos() async {
    if (selectedPhotoIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select photos to delete'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      isDeleting = true;
    });

    try {
      List<String> idsToDelete = selectedPhotoIds.toList();
      
      // Delete photos using PhotoManager [[3]](#__3)
      await PhotoManager.editor.deleteWithIds(idsToDelete);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted ${idsToDelete.length} blurry photos'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Return true to indicate photos were deleted
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error deleting blurry photos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete photos'),
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

  @override
  Widget build(BuildContext context) {
    final selectedCount = selectedPhotoIds.length;
    final selectedSize = (widget.totalSize * selectedCount / widget.totalCount);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
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
      ),
      body: Column(
        children: [
          // Info card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.blur_on, color: Colors.orange, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.totalCount} blurry photos found',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Total size: ${widget.totalSize.toStringAsFixed(1)}GB',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Selection controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (selectedPhotoIds.length == widget.blurryPhotos.length) {
                        selectedPhotoIds.clear();
                      } else {
                        selectedPhotoIds = widget.blurryPhotos.map((p) => p.id).toSet();
                      }
                    });
                  },
                  child: Text(
                    selectedPhotoIds.length == widget.blurryPhotos.length
                        ? 'Deselect All'
                        : 'Select All',
                    style: const TextStyle(color: Colors.orange),
                  ),
                ),
                Text(
                  '$selectedCount selected',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Photo grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: widget.blurryPhotos.length,
              itemBuilder: (context, index) {
                final photo = widget.blurryPhotos[index];
                final isSelected = selectedPhotoIds.contains(photo.id);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        selectedPhotoIds.remove(photo.id);
                      } else {
                        selectedPhotoIds.add(photo.id);
                      }
                    });
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: FutureBuilder<Uint8List?>(
                          future: photo.thumbnailDataWithSize(
                            const ThumbnailSize(200, 200),
                          ),
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
                                child: Icon(Icons.image, color: Colors.grey),
                              ),
                            );
                          },
                        ),
                      ),
                      // Blur indicator overlay
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      // Selection indicator
                      if (isSelected)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange,
                              width: 3,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      // Blur icon
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.blur_on,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Bottom action bar
          Container(
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
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$selectedCount photos selected',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${selectedSize.toStringAsFixed(2)}GB will be freed',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isDeleting ? null : _deleteSelectedPhotos,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 32),
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
                              : const Text(
                                  'Delete',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
