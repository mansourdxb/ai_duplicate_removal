import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../services/thumbnail_service.dart';
import '../models/video_group.dart';
import '../models/video.dart';  // Add this import for the Video class

class VideoGroupWidget extends StatelessWidget {
  final VideoGroup group;
  final List<Video> selectedVideos;
  final Function(Video)? onVideoTap;
  final Function(Video) onVideoSelected;
  final Widget Function(Video) thumbnailBuilder;

  const VideoGroupWidget({
    Key? key,
    required this.group,
    required this.selectedVideos,
    required this.onVideoSelected,
    required this.thumbnailBuilder,
    this.onVideoTap,
  }) : super(key: key);

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final secs = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0 ? '$hours:$minutes:$secs' : '$minutes:$secs';
  }

 String _formatSize(int? bytes) {
  final size = bytes ?? 0;
  if (size < 1024) return '$size B';
  if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
  if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}


  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
  'Group ${group.id?.replaceAll('group_', '') ?? 'Unknown'}',
  style: const TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 18,
  ),
),
                Text(
                  '${group.videos.length} videos · ${_formatSize(group.totalSize.toInt())}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 3/4,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: group.videos.length,
            itemBuilder: (context, index) {
              final video = group.videos[index];
              final isSelected = selectedVideos.contains(video);
              final isBest = index == group.bestVideoIndex;
              
              return GestureDetector(
                onTap: () => onVideoTap?.call(video),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected ? Colors.red : (isBest ? Colors.green : Colors.transparent),
                          width: 2,
                        ),
                      ),
                      child: thumbnailBuilder(video),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        color: Colors.black54,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDuration(video.duration),
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                            ),
                            Text(
  _formatSize(video.size ?? 0),
  style: const TextStyle(color: Colors.white, fontSize: 10),
),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => onVideoSelected(video),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.red : Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isSelected ? Icons.check : Icons.add,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
