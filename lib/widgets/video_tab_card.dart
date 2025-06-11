import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/video_models.dart';  // Update this import path as needed
import '../utils/thumbnail_cache.dart';  // Update this import path as needed

class VideoTabCard extends StatelessWidget {
  final List<VideoGroup> preGroupedVideos;
  final String title;
  final VoidCallback onSeeAllPressed;
  
  const VideoTabCard({
    Key? key,
    required this.preGroupedVideos,
    required this.title,
    required this.onSeeAllPressed,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and "See All" button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: onSeeAllPressed,
                  child: const Text('See All'),
                ),
              ],
            ),
          ),
          
          // Video groups preview (show first 3 groups)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: preGroupedVideos.length > 3 ? 3 : preGroupedVideos.length,
            itemBuilder: (context, index) {
              final group = preGroupedVideos[index];
              return VideoGroupListItem(group: group);
            },
          ),
        ],
      ),
    );
  }
}

// This is a new widget to handle individual list items
class VideoGroupListItem extends StatefulWidget {
  final VideoGroup group;
  
  const VideoGroupListItem({
    Key? key,
    required this.group,
  }) : super(key: key);
  
  @override
  _VideoGroupListItemState createState() => _VideoGroupListItemState();
}

class _VideoGroupListItemState extends State<VideoGroupListItem> {
  Uint8List? thumbnailBytes;
  bool isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }
  
Future<void> _loadThumbnail() async {
  if (widget.group.videos.isEmpty) {
    setState(() {
      isLoading = false;
    });
    return;
  }
  
  final video = widget.group.videos[0];
  // Obtain the file path from AssetEntity
  final file = await video.file;
  
  // Use the static method directly instead of accessing an instance
  final thumbnail = file != null
      ? await ThumbnailCache.getThumbnail(file.path)
      : null;
  
  if (mounted) {
    setState(() {
      thumbnailBytes = thumbnail;
      isLoading = false;
    });
  }
}

  
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _buildThumbnail(),
      title: Text('${widget.group.videos.length} videos'),
      subtitle: Text('Total size: ${widget.group.totalSize}'),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        // Navigate to group details
        print('🎬 DUPLICATE VIDEOS UI: Group tapped');
      },
    );
  }
  
  Widget _buildThumbnail() {
    if (isLoading) {
      return Container(
        width: 80,
        height: 60,
        color: Colors.grey[300],
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    
    if (thumbnailBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.memory(
          thumbnailBytes!,
          width: 80,
          height: 60,
          fit: BoxFit.cover,
        ),
      );
    } else {
      return Container(
        width: 80,
        height: 60,
        color: Colors.grey[300],
        child: const Center(
          child: Icon(Icons.video_file, color: Colors.grey),
        ),
      );
    }
  }
}

