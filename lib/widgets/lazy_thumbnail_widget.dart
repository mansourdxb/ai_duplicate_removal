import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../services/thumbnail_service.dart';

class LazyThumbnailWidget extends StatefulWidget {
  final String videoPath;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool useHero;
  final String? heroTag;

  const LazyThumbnailWidget({
    Key? key,
    required this.videoPath,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.useHero = false,
    this.heroTag,
  }) : super(key: key);

  @override
  LazyThumbnailWidgetState createState() => LazyThumbnailWidgetState();
}

class LazyThumbnailWidgetState extends State<LazyThumbnailWidget> {
  bool _isVisible = false;
  bool _isLoading = false;
  bool _hasError = false;
  Uint8List? _thumbnailBytes;

  @override
  void initState() {
    super.initState();
    // Don't load immediately, wait for visibility
  }

  @override
  void didUpdateWidget(LazyThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the video path changed, reset and prepare to load the new thumbnail
    if (oldWidget.videoPath != widget.videoPath) {
      setState(() {
        _thumbnailBytes = null;
        _isLoading = false;
        _hasError = false;
      });
      
      // If currently visible, load the new thumbnail
      if (_isVisible) {
        _loadThumbnail();
      }
    }
  }

  void _loadThumbnail() async {
  if (_thumbnailBytes != null) return;
  
  setState(() {
    _isLoading = true;
  });
  
  try {
    // Create an instance of ThumbnailService
    final thumbnailService = ThumbnailService();
    
    // Call the method on the instance
    final thumbnail = await thumbnailService.getThumbnail(
      widget.videoPath,
      maxHeight: 240,
      maxWidth: 240,
      quality: 70,
    );
    
    // Add this mounted check
    if (mounted) {
      setState(() {
        _thumbnailBytes = thumbnail;
        _isLoading = false;
      });
    }
  } catch (e) {
    print('Error loading thumbnail: $e');
    // Add this mounted check
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }
}

  @override
  Widget build(BuildContext context) {
    Widget thumbnailWidget;
    
    if (_thumbnailBytes != null) {
      thumbnailWidget = Image.memory(
        _thumbnailBytes!,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWidget();
        },
      );
      
      // Apply Hero animation if requested
      if (widget.useHero) {
        final tag = widget.heroTag ?? 'thumbnail-${widget.videoPath}';
        thumbnailWidget = Hero(
          tag: tag,
          child: thumbnailWidget,
        );
      }
    } else if (_isLoading) {
      thumbnailWidget = _buildLoadingWidget();
    } else if (_hasError) {
      thumbnailWidget = _buildErrorWidget();
    } else {
      thumbnailWidget = _buildPlaceholderWidget();
    }
    
    return VisibilityDetector(
      key: Key('thumbnail-${widget.videoPath}'),
      onVisibilityChanged: (visibilityInfo) {
        final isVisible = visibilityInfo.visibleFraction > 0;
        if (isVisible && !_isVisible) {
          setState(() {
            _isVisible = true;
          });
          _loadThumbnail();
        } else if (!isVisible && _isVisible) {
          setState(() {
            _isVisible = false;
          });
        }
      },
      child: Container(
        width: widget.width,
        height: widget.height,
        color: Colors.black12,
        child: thumbnailWidget,
      ),
    );
  }
  
  Widget _buildLoadingWidget() {
    return widget.placeholder ?? Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white70,
        ),
      ),
    );
  }
  
  Widget _buildErrorWidget() {
    return widget.errorWidget ?? Center(
      child: Icon(
        Icons.broken_image_rounded,
        color: Colors.white70,
        size: 24,
      ),
    );
  }
  
  Widget _buildPlaceholderWidget() {
    return widget.placeholder ?? Center(
      child: Icon(
        Icons.video_file,
        color: Colors.white70,
        size: 24,
      ),
    );
  }
  
  // Public method to force reload the thumbnail
  void reloadThumbnail() {
    setState(() {
      _thumbnailBytes = null;
      _hasError = false;
      _isLoading = false;
    });
    
    if (_isVisible) {
      _loadThumbnail();
    }
  }
  
  // Public method to check if thumbnail is loaded
  bool get isThumbnailLoaded => _thumbnailBytes != null;

  @override
  void dispose() {
    // Cancel any ongoing operations
    super.dispose();
  }
}
