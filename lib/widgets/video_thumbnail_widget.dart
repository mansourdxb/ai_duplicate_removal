import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../services/thumbnail_service.dart';

class VideoThumbnailWidget extends StatefulWidget {
  final String videoPath;
  final double? width;
  final double? height;

  const VideoThumbnailWidget({
    Key? key,
    required this.videoPath,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  _VideoThumbnailWidgetState createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  Uint8List? _thumbnail;
  bool _isLoading = false;
  final ThumbnailService _service = ThumbnailService();

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('thumbnail-${widget.videoPath.hashCode}'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.1 && _thumbnail == null && !_isLoading) {
          _loadThumbnail();
        }
      },
      child: Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey[300],
        child: _buildThumbnail(),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (_thumbnail != null) {
      return Image.memory(
        _thumbnail!,
        fit: BoxFit.cover,
        width: widget.width,
        height: widget.height,
      );
    } else {
      return Center(
        child: _isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                ),
              )
            : Icon(Icons.image, color: Colors.grey[600]),
      );
    }
  }

  void _loadThumbnail() {
    setState(() {
      _isLoading = true;
    });

    _service.getThumbnail(
      widget.videoPath,
      onComplete: (thumbnail) {
        if (mounted) {
          setState(() {
            _thumbnail = thumbnail;
            _isLoading = false;
          });
        }
      },
    );
  }
}
