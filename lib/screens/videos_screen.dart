import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:video_thumbnail/video_thumbnail.dart';
import '../screens/duplicate_videos_screen.dart';
import '../screens/screen_recordings_screen.dart';
import '../screens/short_videos_screen.dart';
import '../models/duplicate_video_group.dart';
import '../models/video_group.dart';
import '../models/video.dart';
import '../utils/video_converter.dart';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import '../utils/thumbnail_cache.dart';
import 'dart:io' show Platform;

class VideosScreen extends StatefulWidget 
{
  const VideosScreen({Key? key}) : super(key: key);

  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> with TickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  bool isLoading = false;
  ReceivePort? _receivePort;
  Isolate? _duplicateDetectionIsolate;
   // Your existing variables
  final GlobalKey _duplicateCardKey = GlobalKey();
  // Storage info
  double usedStorageGB = 103.0;
  double totalStorageGB = 256.0;
  
  // Permission status
  bool hasStoragePermission = false;
  bool isLoadingStorage = true;
  
  // Tab controller
  int selectedTab = 0;
  
  // ===== DUPLICATE VIDEOS =====
  bool isAnalyzingDuplicates = false;
  bool hasAnalyzedDuplicates = false;
  int duplicateVideosCount = 0;
  double duplicateVideosSize = 0.0;
  List<DuplicateVideoGroup> duplicateVideoGroups = [];
  List<AssetEntity> duplicateVideoSamples = [];
  double _duplicateVideosAnalysisProgress = 0.0;
  
  // ===== SCREEN RECORDINGS =====
  List<AssetEntity> allScreenRecordings = [];
  List<AssetEntity> screenRecordingSamples = [];
  int screenRecordingsCount = 0;
  double screenRecordingsSize = 0.0;
  bool isAnalyzingScreenRecordings = false;
  bool hasAnalyzedScreenRecordings = false;
  double _screenRecordingsAnalysisProgress = 0.0;
  
  // ===== SHORT VIDEOS =====
  List<AssetEntity> allShortVideos = [];
  List<AssetEntity> shortVideoSamples = [];
  int shortVideosCount = 0;
  double shortVideosSize = 0.0;
  bool isAnalyzingShortVideos = false;
  bool hasAnalyzedShortVideos = false;
  double _shortVideosAnalysisProgress = 0.0;

 @override
void initState() {
  super.initState();
  _initializeAnimations();

  _checkPermissions().then((_) {
    if (hasStoragePermission) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startDuplicateVideosAnalysis();
        _startScreenRecordingsAnalysis();
        _startShortVideosAnalysis();
      });
    }
  });
}

Future<void> _checkPermissions() async {
  try {
    final status = await Permission.storage.status;
    if (mounted) {
      setState(() {
        hasStoragePermission = status.isGranted;
        isLoadingStorage = false;
      });
    }
  } catch (e) {
    print('Error checking permissions: $e');
    if (mounted) {
      setState(() {
        hasStoragePermission = false;
        isLoadingStorage = false;
      });
    }
  }
}



// Add these methods to your class
Future<void> _preloadDuplicateThumbnails() async {
  if (duplicateVideoSamples.isEmpty) return;

  for (final video in duplicateVideoSamples) {
    try {
      await ThumbnailCache.getThumbnail('thumb_${video.id}');
    } catch (e) {
      debugPrint('Failed to load thumbnail: $e');
    }
  }
}



  void _initializeAnimations() {
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    final progressValue = usedStorageGB / totalStorageGB;
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: progressValue,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
    
    // Start animation
    _progressController.forward();
  }


  void _requestPermissions() async {
    try {
      final status = await Permission.storage.request();
      if (mounted) {
        setState(() {
          hasStoragePermission = status.isGranted;
        });
      }
    } catch (e) {
      print('Error requesting permissions: $e');
    }
  }

Future<void> _analyzeDuplicatesInIsolate(List<AssetEntity> videos) async {
  // Cancel any existing isolate
  _receivePort?.close();
  _duplicateDetectionIsolate?.kill(priority: Isolate.immediate);
  _receivePort = null;
  _duplicateDetectionIsolate = null;
  
  // Create a new receive port
  _receivePort = ReceivePort();
  
  if (mounted) {
    setState(() {
      _duplicateVideosAnalysisProgress = 0.0;
    });
  }
  
  try {
    // Prepare data to send to isolate in batches
    final List<Map<String, dynamic>> videoData = [];
    const int batchSize = 50;
    
    for (int i = 0; i < videos.length; i += batchSize) {
      if (!mounted) return; // Stop if widget is disposed
      
      final end = math.min(i + batchSize, videos.length);
      final batch = videos.sublist(i, end);
      
      for (final video in batch) {
        try {
          final file = await video.file;
          if (file != null) {
            videoData.add({
              'id': video.id,
              'path': file.path,
              'duration': video.duration,
              'size': video.size is int ? video.size : (video.size is double ? (video.size as double).toInt() : 0),
              'width': video.width,
              'height': video.height,
              'createDateTime': video.createDateTime.millisecondsSinceEpoch,
              'title': file.path.split('/').last,
            });
          }
        } catch (e) {
          print('Error processing video ${video.id}: $e');
        }
        
        // Update progress for data preparation phase
        if (mounted) {
          setState(() {
            _duplicateVideosAnalysisProgress = (i + (videoData.length % batchSize)) / videos.length * 0.5;
          });
        }
      }
      
      // Allow UI to update between batches
      await Future.delayed(const Duration(milliseconds: 10));
    }
    
    if (!mounted) return; // Check again after potentially long operation
    
    // Spawn isolate for heavy processing
    _duplicateDetectionIsolate = await Isolate.spawn(
      _duplicateDetectionIsolateEntryPoint,
      {
        'videoData': videoData,
        'sendPort': _receivePort!.sendPort,
      },
    );
    
    // Listen for messages from isolate
    _receivePort!.listen((message) {
      if (!mounted) return; // Important: check if still mounted
      
      if (message is Map<String, dynamic>) {
        if (message.containsKey('progress')) {
          setState(() {
            // Scale progress to 50%-100% range (second half of the process)
            _duplicateVideosAnalysisProgress = 0.5 + (message['progress'] as double) * 0.5;
          });
        } else if (message.containsKey('result')) {
          final List<List<Map<String, dynamic>>> groupsData = 
              List<List<Map<String, dynamic>>>.from(message['result']);
          
          // Convert back to DuplicateVideoGroup objects
          final List<DuplicateVideoGroup> groups = [];
          int totalDuplicates = 0;
          double totalSize = 0.0;
          List<AssetEntity> samples = [];
          
          for (final groupData in groupsData) {
            if (groupData.length <= 1) continue;
            
            final List<AssetEntity> groupVideos = [];
            
            for (final videoData in groupData) {
              final String id = videoData['id'];
              
              try {
                final video = videos.firstWhere((v) => v.id == id);
                groupVideos.add(video);
              } catch (e) {
                print('Warning: Video with ID $id not found in original list');
              }
            }
            
            if (groupVideos.length > 1) {
              // Calculate total size
              double groupSize = 0.0;
              for (final video in groupVideos) {
                final dynamic size = video.size;
                final int fileSize;
                if (size is int) {
                  fileSize = size;
                } else if (size is double) {
                  fileSize = size.round();
                } else {
                  fileSize = 0; // Default value if size is neither int nor double
                }
                groupSize += fileSize;
              }
              
              // Create duplicate group
              final group = DuplicateVideoGroup(
                videos: groupVideos,
                originalIndex: 0,
                selectedIndices: {for (int i = 1; i < groupVideos.length; i++) i},
                duplicateType: 'video',
                groupId: 'group_${DateTime.now().millisecondsSinceEpoch}_${groups.length}',
                totalSize: groupSize,
                confidence: 1.0, // Assuming high confidence for exact matches
              );
              
              groups.add(group);
              
              // Count all videos except the first one in each group as duplicates
              totalDuplicates += groupVideos.length - 1;
              
              // Sum up sizes of all videos except the first one
              for (int i = 1; i < groupVideos.length; i++) {
                final dynamic size = groupVideos[i].size;
                final int fileSize;
                if (size is int) {
                  fileSize = size;
                } else if (size is double) {
                  fileSize = size.round();
                } else {
                  fileSize = 0; // Default value if size is neither int nor double
                }
                totalSize += fileSize / (1024 * 1024 * 1024); // Convert to GB
              }
              
              // Add to samples for UI preview
              if (samples.length < 5 && groupVideos.isNotEmpty) {
                samples.add(groupVideos.first);
              }
            }
          }
          
          setState(() {
            duplicateVideoGroups = groups;
            duplicateVideosCount = totalDuplicates;
            duplicateVideosSize = totalSize;
            duplicateVideoSamples = samples;
            hasAnalyzedDuplicates = true;
            isAnalyzingDuplicates = false;
            _duplicateVideosAnalysisProgress = 1.0;
          });
          // Add this line immediately after the setState block above
        _preloadDuplicateThumbnails();
        } else if (message.containsKey('error')) {
          print('Error in isolate: ${message['error']}');
          setState(() {
            isAnalyzingDuplicates = false;
            hasAnalyzedDuplicates = true;
            _duplicateVideosAnalysisProgress = 0.0;
          });
        }
      }
    }, onDone: () {
      if (mounted) {
        setState(() {
          if (isAnalyzingDuplicates) {
            // Only update if we're still analyzing (might have completed normally)
            isAnalyzingDuplicates = false;
            hasAnalyzedDuplicates = true;
          }
        });
      }
    }, onError: (error) {
      print('Error in isolate communication: $error');
      if (mounted) {
        setState(() {
          isAnalyzingDuplicates = false;
          hasAnalyzedDuplicates = true;
          _duplicateVideosAnalysisProgress = 0.0;
        });
      }
    });
    
  } catch (e) {
    print('Error in _analyzeDuplicatesInIsolate: $e');
    if (mounted) {
      setState(() {
        isAnalyzingDuplicates = false;
        hasAnalyzedDuplicates = true;
        _duplicateVideosAnalysisProgress = 0.0;
      });
    }
  }
}

// Static entry point for the isolate
static void _duplicateDetectionIsolateEntryPoint(Map<String, dynamic> data) {
  final List<Map<String, dynamic>> videoData = data['videoData'];
  final SendPort sendPort = data['sendPort'];
  
  try {
    // Group by duration first (within 1-second tolerance)
    final Map<int, List<Map<String, dynamic>>> durationGroups = {};
    
    for (int i = 0; i < videoData.length; i++) {
      final video = videoData[i];
      final duration = video['duration'];
      final durationKey = (duration / 1000).round(); // Round to nearest second
      
      if (!durationGroups.containsKey(durationKey)) {
        durationGroups[durationKey] = [];
      }
      durationGroups[durationKey]!.add(video);
      
      // Send progress updates
      if (i % 10 == 0) {
        sendPort.send({'progress': i / videoData.length});
      }
    }
    
    // Process each duration group to find actual duplicates
    final List<List<Map<String, dynamic>>> duplicateGroups = [];
    int processedGroups = 0;
    final int totalGroups = durationGroups.length;
    
    for (final durationKey in durationGroups.keys) {
      final group = durationGroups[durationKey]!;
      
      // Only process groups with more than one video
      if (group.length > 1) {
        // Find duplicates within this group
        final List<List<Map<String, dynamic>>> groupDuplicates = _findDuplicatesInGroup(group);
        duplicateGroups.addAll(groupDuplicates);
      }
      
      processedGroups++;
      sendPort.send({'progress': processedGroups / totalGroups});
    }
    
    // Send final result
    sendPort.send({'result': duplicateGroups});
  } catch (e) {
    print('Error in duplicate detection isolate: $e');
    sendPort.send({'error': e.toString()});
  }
}

// Helper method to find duplicates in a group
static List<List<Map<String, dynamic>>> _findDuplicatesInGroup(List<Map<String, dynamic>> group) {
  List<List<Map<String, dynamic>>> result = [];
  Set<int> processedIndices = {};
  
  for (int i = 0; i < group.length; i++) {
    if (processedIndices.contains(i)) continue;
    
    List<Map<String, dynamic>> currentGroup = [group[i]];
    processedIndices.add(i);
    
    for (int j = i + 1; j < group.length; j++) {
      if (processedIndices.contains(j)) continue;
      
      if (_areVideosLikelyDuplicates(group[i], group[j])) {
        currentGroup.add(group[j]);
        processedIndices.add(j);
      }
    }
    
    if (currentGroup.length > 1) {
      result.add(currentGroup);
    }
  }
  
  return result;
}

static bool _areVideosLikelyDuplicates(Map<String, dynamic> video1, Map<String, dynamic> video2) {
  // 1. Compare durations (should be very close)
  final duration1 = video1['duration'] as int;
  final duration2 = video2['duration'] as int;
  final durationDiff = (duration1 - duration2).abs();
  if (durationDiff > 2000) return false; // More than 2 seconds difference
  
  // 2. Compare resolutions
  final width1 = video1['width'] as int;
  final height1 = video1['height'] as int;
  final width2 = video2['width'] as int;
  final height2 = video2['height'] as int;
  
  // Allow for resolution differences due to different encodings
  if (width1 == width2 && height1 == height2) {
    // Exact resolution match - strong indicator
    // Now check file size
    final size1 = video1['size'] as int?;
    final size2 = video2['size'] as int?;
    
    if (size1 != null && size2 != null) {
      // Allow for up to 20% size difference (different encodings/quality)
      final sizeDiff = (size1 - size2).abs();
      final sizeRatio = sizeDiff / math.max(size1, size2);
      
      if (sizeRatio < 0.2) {
        return true; // Very likely duplicates
      }
    }
    
    // Even without size comparison, same resolution and duration is a good indicator
    return true;
  }
  
  // Check for common resolution scaling patterns
  final aspectRatio1 = width1 / height1;
  final aspectRatio2 = width2 / height2;
  final aspectRatioDiff = (aspectRatio1 - aspectRatio2).abs();
  
  if (aspectRatioDiff < 0.1) {
    // Same aspect ratio - could be same video at different resolutions
    // Check if one is a scaled version of the other
    if ((width1 % width2 == 0 || width2 % width1 == 0) && 
        (height1 % height2 == 0 || height2 % height1 == 0)) {
      return true;
    }
  }
  
  return false;
}

// Add this debug code to check available properties
Future<void> debugAssetEntity(AssetEntity asset) async {
  print('🔍 AssetEntity debug:');
  print('- id: ${asset.id}');
  print('- title: ${asset.title}');
  print('- type: ${asset.type}');
  print('- duration: ${asset.duration}');
  print('- size: ${asset.size}');
  print('- width: ${asset.width}');
  print('- height: ${asset.height}');
  // Add more properties as needed
}


Future<void> _processThumbnailsInBatches(List<AssetEntity> videos, {int batchSize = 10}) async {
  for (int i = 0; i < videos.length; i += batchSize) {
    final int end = math.min(i + batchSize, videos.length);
    final batch = videos.sublist(i, end);
    
    // Process batch in parallel
    await Future.wait(
      batch.map((video) async {
        try {
          await ThumbnailCache.generateAndCacheThumbnail(video);
        } catch (e) {
          print('Error generating thumbnail for ${video.id}: $e');
        }
      }),
    );
    
    // Give the UI thread a chance to breathe
    await Future.delayed(const Duration(milliseconds: 50));
  }
}

// Add this method to safely get a file with timeout
Future<File?> _getFileWithTimeout(AssetEntity asset, {Duration timeout = const Duration(seconds: 5)}) async {
  try {
    return await asset.file.timeout(timeout, onTimeout: () {
      print('Timeout getting file for asset ${asset.id}');
      return null;
    });
  } catch (e) {
    print('Error getting file for asset ${asset.id}: $e');
    return null;
  }
}

Future<void> _startDuplicateVideosAnalysis() async {
    print('DEBUG: _startDuplicateVideosAnalysis CALLED');
  print('DEBUG: isAnalyzingDuplicates = $isAnalyzingDuplicates');
  if (isAnalyzingDuplicates) return;
  setState(() {
    isAnalyzingDuplicates = true;
  });
  try {
    print('🎬 Getting videos to analyze for duplicates...');
    
    // Add a delay to ensure the UI updates with the loading indicator
    await Future.delayed(Duration(milliseconds: 100));
    
    // Use your existing method for getting videos
    // Replace this with your actual method for getting videos
    final videos = await _getVideosForAnalysis();
    print('📊 Found ${videos.length} videos to analyze for duplicates');
    
    // Use your existing method for finding duplicates
    // Replace this with your actual method for finding duplicates
    final results = await _findDuplicateVideos(videos);
    
    // Ensure we're updating the state correctly
    if (mounted) {
setState(() {
        // Update with your actual property names
        duplicateVideoGroups = results.groups;
        duplicateVideoSamples = duplicateVideoGroups
    .expand((group) => group.videos)
    .take(3)
    .toList();
      });

      await _preloadDuplicateThumbnails();

      if (mounted) {
        setState(() {
          duplicateVideosCount = results.totalCount;
          duplicateVideosSize = results.totalSize;
          hasAnalyzedDuplicates = true;
          isAnalyzingDuplicates = false;
        });
      }
    }
    
    print('✅ DUPLICATES: Analysis complete - $duplicateVideosCount duplicate videos found');
    
    // Show a snackbar with the results
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Found $duplicateVideosCount duplicate videos'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    print('❌ Error analyzing duplicates: $e');
    
    if (mounted) {
      setState(() {
        isAnalyzingDuplicates = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error analyzing duplicates'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

Future<List<Video>> _getVideosForAnalysis() async {
  print('🎬 Getting videos to analyze for duplicates...');
  
  try {
    // Request photo manager permission
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.hasAccess) {
      print('❌ No permission to access media');
      return [];
    }

    // Get all video assets
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      onlyAll: true,
    );

    if (paths.isEmpty) {
      print('❌ No video paths found');
      return [];
    }

    final AssetPathEntity allVideos = paths.first;
    final List<AssetEntity> assets = await allVideos.getAssetListRange(
      start: 0,
      end: await allVideos.assetCountAsync,
    );
    
    print('📊 Found ${assets.length} videos to analyze');
    
    // Convert AssetEntity to Video model
    List<Video> videos = [];
    for (final asset in assets) {
      try {
        final file = await asset.file;
        if (file != null) {
          // Safely handle the size property
          int sizeInBytes = 0;
          
          if (asset.size is int) {
            sizeInBytes = asset.size as int;
          } else {
            // If asset.size is not an int, try to get size from file
            try {
              sizeInBytes = await file.length();
            } catch (e) {
              print('❌ Error getting file size for ${asset.id}: $e');
            }
          }
          
          final double sizeInGB = sizeInBytes / (1024 * 1024 * 1024);
          
         videos.add(Video(
  id: asset.id,
  title: asset.title ?? file.path.split('/').last,
  path: file.path,
  size: sizeInBytes,
  duration: asset.duration,
  asset: asset,
  width: asset.width,
  height: asset.height,
  dateCreated: asset.createDateTime, // Add this line
));
        }
      } catch (e) {
        print('❌ Error processing video ${asset.id}: $e');
      }
    }
    
    return videos;
  } catch (e) {
    print('❌ Error getting videos: $e');
    return [];
  }
}

Future<DuplicateAnalysisResult> _findDuplicateVideos(List<Video> videos) async {
  print('🔍 Finding duplicates among ${videos.length} videos...');
  
  List<DuplicateVideoGroup> groups = [];
  int totalCount = 0;
  double totalSize = 0.0;
  
  try {
    // Group videos by similar duration (within 1 second)
    Map<int, List<Video>> durationGroups = {};
    
    for (final video in videos) {
      // Extract duration from filename or use a default value
      // This is a simplified approach - you may need to extract actual duration
      final String path = video.path;
      final File file = File(path);
      
      if (!file.existsSync()) continue;
      
      // Group by file size first (rounded to nearest MB)
      final int fileSizeKey = ((video.size / (1024 * 1024))).round(); // Size in MB
      
      durationGroups.putIfAbsent(fileSizeKey, () => []).add(video);
    }
    
    // Find duplicates within each duration group
    for (final videos in durationGroups.values) {
      if (videos.length <= 1) continue; // Skip groups with only one video
      
      // For videos with similar duration, check for duplicates
      for (int i = 0; i < videos.length; i++) {
        List<Video> duplicates = [];
        duplicates.add(videos[i]);
        
        for (int j = i + 1; j < videos.length; j++) {
          // Compare videos[i] and videos[j]
          // This is a simplified comparison - you may want to use more sophisticated methods
          if (_areVideosDuplicate(videos[i], videos[j])) {
            duplicates.add(videos[j]);
          }
        }
        
        if (duplicates.length > 1) {
          // Calculate total size of duplicates (excluding the first one)
          double groupSize = 0.0;
          for (int k = 1; k < duplicates.length; k++) {
            groupSize += duplicates[k].size / (1024 * 1024 * 1024); // Convert bytes to GB
          }
          
          // Create duplicate group
          final group = DuplicateVideoGroup(
            videos: duplicates.map((v) => AssetEntity(
              id: v.id,
              typeInt: 2, // Type for video
              width: 0,
              height: 0,
              duration: 0,
              orientation: 0,
            )).toList(),
            originalIndex: 0,
            selectedIndices: {for (int k = 1; k < duplicates.length; k++) k},
            duplicateType: 'video',
            groupId: 'group_${DateTime.now().millisecondsSinceEpoch}_${groups.length}',
            totalSize: groupSize * 1024 * 1024 * 1024, // Convert GB to bytes
            confidence: 1.0,
          );
          
          groups.add(group);
          totalCount += duplicates.length - 1;
          totalSize += groupSize;
          
          // Remove duplicates from further consideration
          videos.removeWhere((v) => duplicates.contains(v) && v != duplicates[0]);
        }
      }
    }
    
    print('✅ Found ${groups.length} duplicate groups with $totalCount total duplicates');
    return DuplicateAnalysisResult(
      groups: groups,
      totalCount: totalCount,
      totalSize: totalSize,
    );
    
  } catch (e) {
    print('❌ Error finding duplicates: $e');
    return DuplicateAnalysisResult(
      groups: [],
      totalCount: 0,
      totalSize: 0.0,
    );
  }
}

// Helper method to determine if two videos are duplicates
bool _areVideosDuplicate(Video video1, Video video2) {
  // Simple comparison based on file size
  // You can enhance this with more sophisticated checks
  
  // Check if file sizes are within 5% of each other
  final double sizeRatio = (video1.size / (1024 * 1024 * 1024)) / (video2.size / (1024 * 1024 * 1024));
  if (sizeRatio < 0.95 || sizeRatio > 1.05) return false;
  
  // Check if filenames are similar (excluding extensions)
  final String name1 = video1.title.split('.').first;
  final String name2 = video2.title.split('.').first;
  
  // If names are very similar
  if (name1 == name2) return true;
  
  // Check for common patterns in duplicate filenames
  // e.g., "video (1).mp4" and "video.mp4"
  final RegExp copyPattern = RegExp(r'(.*) \(\d+\)$');
  final match1 = copyPattern.firstMatch(name1);
  final match2 = copyPattern.firstMatch(name2);
  
  if (match1 != null && name2 == match1.group(1)) return true;
  if (match2 != null && name1 == match2.group(1)) return true;
  
  // For more accurate detection, you should implement:
  // 1. Video duration comparison
  // 2. Resolution comparison
  // 3. Frame sampling and comparison
  // 4. Perceptual hashing
  
  return false;
}
// Add this to your class
void _debugDuplicateAnalysis() {
  print('🔍 DEBUG: Duplicate analysis state:');
  print('🔍 isAnalyzingDuplicates: $isAnalyzingDuplicates');
  print('🔍 hasAnalyzedDuplicates: $hasAnalyzedDuplicates');
  print('🔍 duplicateVideosCount: $duplicateVideosCount');
  print('🔍 duplicateVideosSize: $duplicateVideosSize');
  print('🔍 duplicateVideoGroups: ${duplicateVideoGroups.length} groups');
}

// Call this at the beginning and end of _startDuplicateVideosAnalysis


Future<List<Map<String, dynamic>>> _prepareVideoDataInBatches(List<AssetEntity> videos) async {
  final List<Map<String, dynamic>> videoData = [];
  const batchSize = 50;
  
  for (int i = 0; i < videos.length; i += batchSize) {
    final end = math.min(i + batchSize, videos.length);
    final batch = videos.sublist(i, end);
    
    for (final video in batch) {
      final file = await video.file;
      if (file != null) {
        videoData.add({
          'id': video.id,
          'path': file.path,
          'duration': video.duration,
          'size': video.size,
          'width': video.width,
          'height': video.height,
          'createDateTime': video.createDateTime.millisecondsSinceEpoch,
        });
      }
      
      // Update progress
      final progress = (i + videoData.length) / videos.length;
      if (mounted) {
        setState(() {
          _duplicateVideosAnalysisProgress = progress * 0.5; // First half of progress is data preparation
        });
      }
    }
    
    // Allow UI to update between batches
    await Future.delayed(const Duration(milliseconds: 10));
  }
  
  return videoData;
}


Future<List<DuplicateVideoGroup>> _findAndGroupDuplicateVideos(List<AssetEntity> allVideos) async {
  print('\U0001F50D Starting enhanced duplicate detection of ${allVideos.length} videos');
  
  List<DuplicateVideoGroup> groups = [];
  
  try {
    // Step 1: First pass - group by duration (with small tolerance)
    Map<String, List<AssetEntity>> durationGroups = {};
    
    for (int i = 0; i < allVideos.length; i++) {
      var video = allVideos[i];
      
      try {
        // Round duration to nearest second to allow for slight differences
        int roundedDuration = (video.duration / 1000).round();
        String durationKey = roundedDuration.toString();
        
        durationGroups.putIfAbsent(durationKey, () => []).add(video);
        
        // Update progress
        if (i % 10 == 0) {
          print('Processed ${i + 1}/${allVideos.length}');
          
          if (mounted) {
            setState(() {
              _duplicateVideosAnalysisProgress = (i + 1) / (2 * allVideos.length);
            });
          }
        }
      } catch (e) {
        continue;
      }
    }
    
    print('Created ${durationGroups.length} duration groups');
    
    // Step 2: Second pass - compare thumbnails within duration groups
    int processedGroups = 0;
    int totalGroups = durationGroups.entries.where((e) => e.value.length > 1).length;
    
    for (var entry in durationGroups.entries) {
      if (entry.value.length > 1) {
        List<AssetEntity> potentialDuplicates = entry.value;
        
        // Compare thumbnails within this group
        await _findDuplicatesByThumbnail(potentialDuplicates, groups);
        
        processedGroups++;
        if (mounted) {
          setState(() {
            _duplicateVideosAnalysisProgress = 0.5 + (processedGroups / (totalGroups * 2));
          });
        }
      }
    }
    
    print('✅ Found ${groups.length} groups of duplicate videos');
    return groups;
    
  } catch (e) {
    print('❌ Error: $e');
    return [];
  }
}

Future<void> _findDuplicatesByThumbnail(List<AssetEntity> videos, List<DuplicateVideoGroup> groups) async {
  // Create map to track which videos have been grouped
  Set<String> processedIds = {};
  
  // For each video, extract thumbnail and compare with others
  for (int i = 0; i < videos.length; i++) {
    if (processedIds.contains(videos[i].id)) continue;
    
    List<AssetEntity> similarVideos = [videos[i]];
    List<double> similarities = [];
    
    // Get thumbnail for the reference video
    Uint8List? refThumbnail = await _getVideoThumbnail(videos[i]);
    if (refThumbnail == null) continue;
    
    for (int j = i + 1; j < videos.length; j++) {
      if (processedIds.contains(videos[j].id)) continue;
      
      // Get thumbnail for comparison video
      Uint8List? compThumbnail = await _getVideoThumbnail(videos[j]);
      if (compThumbnail == null) continue;
      
      // Compare thumbnails
      double similarity = await _compareThumbnails(refThumbnail, compThumbnail);
      
      // If similarity exceeds threshold, add to group
      if (similarity > 0.85) {
        similarVideos.add(videos[j]);
        similarities.add(similarity);
        processedIds.add(videos[j].id);
      }
    }
    
    // If we found similar videos, create a group
    if (similarVideos.length > 1) {
      // Sort by creation time
      similarVideos.sort((a, b) {
        if (a.createDateTime == null && b.createDateTime == null) return 0;
        if (a.createDateTime == null) return 1;
        if (b.createDateTime == null) return -1;
        return a.createDateTime!.compareTo(b.createDateTime!);
      });
      
      // Calculate average similarity
      double avgSimilarity = similarities.isNotEmpty 
          ? similarities.reduce((a, b) => a + b) / similarities.length 
          : 0.95;
      
      // Estimate size
      double estimatedSize = await _calculateEstimatedSize(similarVideos.sublist(1));
      
      DuplicateVideoGroup group = DuplicateVideoGroup(
        videos: similarVideos,
        originalIndex: 0,
        selectedIndices: Set.from(List.generate(similarVideos.length - 1, (i) => i + 1)),
        duplicateType: avgSimilarity > 0.95 ? 'Identical' : 'Similar',
        groupId: 'enhanced_${DateTime.now().millisecondsSinceEpoch}_${groups.length}',
        totalSize: estimatedSize,
        confidence: avgSimilarity,
      );
      
      groups.add(group);
      processedIds.add(videos[i].id);
    }
  }
}

// Add this method to optimize thumbnail quality
ThumbnailSize _getThumbnailSize() {
  // Adjust based on device performance or screen size
  if (Platform.isIOS) {
    // Higher quality for iOS devices
    return const ThumbnailSize(240, 240);
  } else {
    // Standard quality for other devices
    return const ThumbnailSize(200, 200);
  }
}

Future<Uint8List?> _getCachedThumbnail(AssetEntity video) async {
  final String cacheKey = 'thumb_${video.id}';
  
  final Uint8List? cachedThumb = await ThumbnailCache.getThumbnail(cacheKey);
  if (cachedThumb != null) {
    return cachedThumb;
  }
  
  final Uint8List? thumb = await video.thumbnailDataWithSize(
    const ThumbnailSize(200, 200),
  );
  
  if (thumb != null) {
    await ThumbnailCache.setThumbnail(cacheKey, thumb);
  }
  
  return thumb;
}
Future<Uint8List?> _getVideoThumbnail(AssetEntity video) async {
  try {
    print('🖼️ Generating thumbnail for video ${video.id}');
    
    // First check cache
    final String cacheKey = 'thumb_${video.id}';
    final Uint8List? cachedThumb = await ThumbnailCache.getThumbnail(cacheKey);
    
    if (cachedThumb != null) {
      print('✅ Found cached thumbnail for ${video.id}');
      return cachedThumb;
    }
    
    // Get file
    print('📁 Getting file for video ${video.id}');
    final File? file = await _getFileWithTimeout(video);
    if (file == null) {
      print('❌ Failed to get file for video ${video.id}');
      return null;
    }
    
    print('📁 File path: ${file.path}');
    print('⏱️ Generating thumbnail at time: ${(video.duration / 3).round()}ms');
    
    // Generate thumbnail
    final Uint8List? thumbData = await VideoThumbnail.thumbnailData(
      video: file.path,
      imageFormat: ImageFormat.JPEG,
      quality: 50,
      maxWidth: 128,
      timeMs: (video.duration / 3).round(),
    );
    
    if (thumbData != null) {
      print('✅ Successfully generated thumbnail for ${video.id} (${thumbData.length} bytes)');
      await ThumbnailCache.setThumbnail(cacheKey, thumbData);
      return thumbData;
    } else {
      print('❌ Failed to generate thumbnail for ${video.id}');
      return null;
    }
  } catch (e) {
    print('❌ Error generating thumbnail for ${video.id}: $e');
    return null;
  }
}

Future<double> _compareThumbnails(Uint8List thumbnail1, Uint8List thumbnail2) async {
  try {
    // Simple pixel-based comparison for now
    // Convert both thumbnails to same size if needed
    
    // Calculate difference between images
    int totalPixels = math.min(thumbnail1.length, thumbnail2.length);
    int diffCount = 0;
    
    for (int i = 0; i < totalPixels; i++) {
      int diff = (thumbnail1[i] - thumbnail2[i]).abs();
      if (diff > 30) diffCount++;  // Threshold for considering pixels different
    }
    
    // Calculate similarity (1.0 = identical, 0.0 = completely different)
    double similarity = 1.0 - (diffCount / totalPixels);
    return similarity;
    
    // Note: For production use, replace this with a proper perceptual hash comparison
    // like pHash, dHash, or aHash algorithm
  } catch (e) {
    print('Error comparing thumbnails: $e');
    return 0.0;
  }
}


  // ===== SCREEN RECORDINGS ANALYSIS =====
  
  Future<void> _startScreenRecordingsAnalysis() async {
    print('🎬 STARTING screen recordings analysis...');
    
    if (isAnalyzingScreenRecordings) {
      print('⚠️ Screen recordings analysis already running, skipping...');
      return;
    }
    
    setState(() {
      isAnalyzingScreenRecordings = true;
      _screenRecordingsAnalysisProgress = 0.0;
    });

    try {
      // Request photo manager permission
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (!ps.hasAccess) {
        setState(() {
          isAnalyzingScreenRecordings = false;
        });
        return;
      }

      // Get all video assets
      print('🎬 Getting videos to analyze for screen recordings...');
      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        type: RequestType.video,
        onlyAll: true,
      );

      if (paths.isNotEmpty) {
        final AssetPathEntity allVideos = paths.first;
        final List<AssetEntity> assets = await allVideos.getAssetListRange(
          start: 0,
          end: await allVideos.assetCountAsync,
        );
        
        print('📊 Found ${assets.length} videos to analyze for screen recordings');
        
        if (assets.isEmpty) {
          setState(() {
            _screenRecordingsAnalysisProgress = 1.0;
            isAnalyzingScreenRecordings = false;
            hasAnalyzedScreenRecordings = true;
          });
          return;
        }

        // Find screen recordings
        List<AssetEntity> screenRecordings = await _findScreenRecordings(assets);
        
        // Calculate total size of screen recordings
        double totalSizeGB = await _calculateEstimatedSize(screenRecordings);
        
        // Get sample screen recordings for display (first 3)
        List<AssetEntity> samples = screenRecordings.take(3).toList();

        setState(() {
          allScreenRecordings = screenRecordings;
          screenRecordingsCount = screenRecordings.length;
          screenRecordingsSize = totalSizeGB;
          screenRecordingSamples = samples;
          _screenRecordingsAnalysisProgress = 1.0;
          isAnalyzingScreenRecordings = false;
          hasAnalyzedScreenRecordings = true;
        });

        print('✅ SCREEN RECORDINGS: Analysis complete - ${screenRecordings.length} screen recordings found');

      } else {
        setState(() {
          isAnalyzingScreenRecordings = false;
          hasAnalyzedScreenRecordings = true;
          _screenRecordingsAnalysisProgress = 1.0;
        });
      }
    } catch (e) {
      print('❌ Error analyzing screen recordings: $e');
      setState(() {
        isAnalyzingScreenRecordings = false;
        hasAnalyzedScreenRecordings = true;
        _screenRecordingsAnalysisProgress = 1.0;
      });
    }
  }

  Future<List<AssetEntity>> _findScreenRecordings(List<AssetEntity> assets) async {
    List<AssetEntity> screenRecordings = [];
    
    for (int i = 0; i < assets.length; i++) {
      final asset = assets[i];
      
      // Update progress
      if (i % 50 == 0) {
        setState(() {
          _screenRecordingsAnalysisProgress = i / assets.length;
        });
      }
      
      try {
        // Check if it's a screen recording based on multiple criteria
        bool isScreenRecording = await _isScreenRecording(asset);
        
        if (isScreenRecording) {
          screenRecordings.add(asset);
        }
        
      } catch (e) {
        print('❌ Error checking screen recording for ${asset.id}: $e');
      }
    }
    
    return screenRecordings;
  }

  Future<bool> _isScreenRecording(AssetEntity asset) async {
    try {
      // Method 1: Check filename patterns
      String? title = asset.title;
      if (title != null) {
        String lowerTitle = title.toLowerCase();
        
        // Common screen recording filename patterns
        List<String> screenRecordingPatterns = [
          'screen_recording',
          'screenrecord',
          'screen-recording',
          'record',
          'screen_capture',
          'screen-capture',
          'screencast',
        ];
        
        for (String pattern in screenRecordingPatterns) {
          if (lowerTitle.contains(pattern)) {
            return true;
          }
        }
        
        // iOS screen recording pattern: Screen Recording YYYY-MM-DD at HH.MM.SS
        RegExp iosPattern = RegExp(r'screen recording \d{4}-\d{2}-\d{2} at \d{2}\.\d{2}\.\d{2}');
        if (iosPattern.hasMatch(lowerTitle)) {
          return true;
        }
        
        // Android screen recording pattern: screenrecord-YYYYMMDD-HHMMSS
        RegExp androidPattern = RegExp(r'screenrecord-\d{8}-\d{6}');
        if (androidPattern.hasMatch(lowerTitle)) {
          return true;
        }
      }
      
      // Method 2: Check if dimensions match common screen resolutions
      if (await _hasScreenResolution(asset)) {
        return true;
      }
      
      // Method 3: Check duration (screen recordings are typically longer than 10 seconds)
      if (asset.duration >= 10) {
        return true;
      }
      
      return false;
      
    } catch (e) {
      print('❌ Error in screen recording detection: $e');
      return false;
    }
  }

  Future<bool> _hasScreenResolution(AssetEntity asset) async {
    try {
      // Common mobile screen resolutions (width x height or height x width)
      List<List<int>> commonScreenResolutions = [
        // iPhone resolutions
        [1170, 2532], [1125, 2436], [1242, 2688], [828, 1792], [750, 1334], [640, 1136],
        // Android resolutions
        [1080, 2340], [1080, 2400], [1440, 3200], [1440, 2960], [1080, 1920], [720, 1280],
        // iPad resolutions
        [1620, 2160], [1668, 2388], [1536, 2048], [1024, 1366],
      ];
      
      int width = asset.width;
      int height = asset.height;
      
      for (List<int> resolution in commonScreenResolutions) {
        if ((width == resolution[0] && height == resolution[1]) ||
            (width == resolution[1] && height == resolution[0])) {
          return true;
        }
      }
      
      // Check for common aspect ratios that might be screen recordings
      double aspectRatio = width > height ? width / height : height / width;
      
      // Common mobile aspect ratios
      List<double> commonAspectRatios = [16/9, 18/9, 19.5/9, 20/9, 4/3, 3/2];
      
      for (double ratio in commonAspectRatios) {
        if ((aspectRatio - ratio).abs() < 0.1) {
          // If it matches a mobile aspect ratio and is reasonably sized
          int largerDimension = width > height ? width : height;
          if (largerDimension >= 1000) { // Reasonable screen size
            return true;
          }
        }
      }
      
      return false;
      
    } catch (e) {
      print('❌ Error checking screen recording dimensions: $e');
      return false;
    }
  }

  // ===== SHORT VIDEOS ANALYSIS =====
  
  Future<void> _startShortVideosAnalysis() async {
    print('🎬 STARTING short videos analysis...');
    
    if (isAnalyzingShortVideos) {
      print('⚠️ Short videos analysis already running, skipping...');
      return;
    }
    
    setState(() {
      isAnalyzingShortVideos = true;
      _shortVideosAnalysisProgress = 0.0;
    });

    try {
      // Request photo manager permission
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (!ps.hasAccess) {
        setState(() {
          isAnalyzingShortVideos = false;
        });
        return;
      }

      // Get all video assets
      print('🎬 Getting videos to analyze for short videos...');
      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        type: RequestType.video,
        onlyAll: true,
      );

      if (paths.isNotEmpty) {
        final AssetPathEntity allVideos = paths.first;
        final List<AssetEntity> assets = await allVideos.getAssetListRange(
          start: 0,
          end: await allVideos.assetCountAsync,
        );
        
        print('📊 Found ${assets.length} videos to analyze for short videos');
        
        if (assets.isEmpty) {
          setState(() {
            _shortVideosAnalysisProgress = 1.0;
            isAnalyzingShortVideos = false;
            hasAnalyzedShortVideos = true;
          });
          return;
        }

        // Find short videos (less than 10 seconds)
        List<AssetEntity> shortVideos = await _findShortVideos(assets);
        
        // Calculate total size of short videos
        double totalSizeGB = await _calculateEstimatedSize(shortVideos);
        
        // Get sample short videos for display (first 3)
        List<AssetEntity> samples = shortVideos.take(3).toList();

        setState(() {
          allShortVideos = shortVideos;
          shortVideosCount = shortVideos.length;
          shortVideosSize = totalSizeGB;
          shortVideoSamples = samples;
          _shortVideosAnalysisProgress = 1.0;
          isAnalyzingShortVideos = false;
          hasAnalyzedShortVideos = true;
        });

        print('✅ SHORT VIDEOS: Analysis complete - ${shortVideos.length} short videos found');

      } else {
        setState(() {
          isAnalyzingShortVideos = false;
          hasAnalyzedShortVideos = true;
          _shortVideosAnalysisProgress = 1.0;
        });
      }
    } catch (e) {
      print('❌ Error analyzing short videos: $e');
      setState(() {
        isAnalyzingShortVideos = false;
        hasAnalyzedShortVideos = true;
        _shortVideosAnalysisProgress = 1.0;
      });
    }
  }

  Future<List<AssetEntity>> _findShortVideos(List<AssetEntity> assets) async {
    List<AssetEntity> shortVideos = [];
    
    for (int i = 0; i < assets.length; i++) {
      final asset = assets[i];
      
      // Update progress
      if (i % 50 == 0) {
        setState(() {
          _shortVideosAnalysisProgress = i / assets.length;
        });
      }
      
      try {
        // Check if it's a short video (less than 10 seconds)
        if (asset.duration <= 10) {
          shortVideos.add(asset);
        }
        
      } catch (e) {
        print('❌ Error checking short video for ${asset.id}: $e');
      }
    }
    
    return shortVideos;
  }

  // ===== COMMON HELPER METHODS =====
  
  Future<double> _calculateEstimatedSize(List<AssetEntity> videos) async {
    double totalSize = 0.0;
    
    for (var video in videos) {
      // Estimate file size based on resolution and duration
      int totalPixels = video.width * video.height;
      int durationSeconds = video.duration;
      double estimatedMB;
      
      // Estimate based on typical compression ratios and duration
      if (totalPixels < 1000000) {
        estimatedMB = 0.2 * durationSeconds; // Low res videos
      } else if (totalPixels < 3000000) {
        estimatedMB = 0.5 * durationSeconds; // Medium res videos
      } else if (totalPixels < 8000000) {
        estimatedMB = 1.0 * durationSeconds; // High res videos
      } else {
        estimatedMB = 2.0 * durationSeconds; // Ultra high res videos
      }
      
      totalSize += estimatedMB;
    }
    
    return totalSize / 1024; // Convert MB to GB
  }

  Future<void> refreshVideoData({String? analysisType}) async {
    print('🔄 Refreshing video data after deletion for: ${analysisType ?? "all"}');
    
    setState(() {
      isLoading = true;
    });
    
    try {
      if (analysisType == null || analysisType == 'all') {
        // Clear ALL data (for full refresh)
        setState(() {
          _clearAllAnalysisData();
          isLoading = false;
        });
        
        // Restart all analyses
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _startDuplicateVideosAnalysis();
          _startScreenRecordingsAnalysis();
          _startShortVideosAnalysis();
        });
        
        _showRefreshMessage('All analyses restarted!');
        
      } else if (analysisType == 'screenRecordings') {
        // Only clear screen recordings data
        setState(() {
          allScreenRecordings.clear();
          screenRecordingSamples.clear();
          screenRecordingsCount = 0;
          screenRecordingsSize = 0.0;
          _screenRecordingsAnalysisProgress = 0.0;
          isAnalyzingScreenRecordings = false;
          hasAnalyzedScreenRecordings = false;
          isLoading = false;
        });
        
        // Only restart screen recordings analysis
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _startScreenRecordingsAnalysis();
        });
        
        _showRefreshMessage('Screen recordings re-analyzing...');
        
      } else if (analysisType == 'shortVideos') {
        // Only clear short videos data
        setState(() {
          allShortVideos.clear();
          shortVideoSamples.clear();
          shortVideosCount = 0;
          shortVideosSize = 0.0;
          _shortVideosAnalysisProgress = 0.0;
          isAnalyzingShortVideos = false;
          hasAnalyzedShortVideos = false;
          isLoading = false;
        });
        
        // Only restart short videos analysis
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _startShortVideosAnalysis();
        });
        
        _showRefreshMessage('Short videos re-analyzing...');
        
      } else if (analysisType == 'duplicates') {
        // Only clear duplicates data
        setState(() {
          duplicateVideoGroups.clear();
          duplicateVideoSamples.clear();
          duplicateVideosCount = 0;
          duplicateVideosSize = 0.0;
          _duplicateVideosAnalysisProgress = 0.0;
          isAnalyzingDuplicates = false;
          hasAnalyzedDuplicates = false;
          isLoading = false;
        });
        
        // Only restart duplicates analysis
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _startDuplicateVideosAnalysis();
        });
        
        _showRefreshMessage('Duplicates re-analyzing...');
      }
    } catch (e) {
      print('❌ Error refreshing video data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // Helper method to clear all analysis data
  void _clearAllAnalysisData() {
    // Clear duplicate data
    duplicateVideoGroups.clear();
    duplicateVideoSamples.clear();
    duplicateVideosCount = 0;
    duplicateVideosSize = 0.0;
    _duplicateVideosAnalysisProgress = 0.0;
    isAnalyzingDuplicates = false;
    hasAnalyzedDuplicates = false;
    
    // Clear screen recordings data
    allScreenRecordings.clear();
    screenRecordingSamples.clear();
    screenRecordingsCount = 0;
    screenRecordingsSize = 0.0;
    _screenRecordingsAnalysisProgress = 0.0;
    isAnalyzingScreenRecordings = false;
    hasAnalyzedScreenRecordings = false;
    
    // Clear short videos data
    allShortVideos.clear();
    shortVideoSamples.clear();
    shortVideosCount = 0;
    shortVideosSize = 0.0;
    _shortVideosAnalysisProgress = 0.0;
    isAnalyzingShortVideos = false;
    hasAnalyzedShortVideos = false;
  }

  // Helper method to show refresh messages
  void _showRefreshMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
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
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam,
              color: Colors.red,
              size: 20,
            ),
            const SizedBox(width: 6),
            const Text(
              ' Videos',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const SizedBox(height: 20),
            const SizedBox(height: 16),
            _buildAnalysisCards(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildAnalysisCards() {
    return Column(
      children: [
        _buildDuplicateVideosCard(),
        
        const SizedBox(height: 12),
        
        _buildScreenRecordingsCard(),
        
        const SizedBox(height: 12),
        
        _buildShortVideosCard(),
      ],
    );
  }

// Add this method to your class
void _debugWidgetTree() {
  print('🔍 DEBUG: Widget tree for duplicate videos card:');
  print('🔍 hasAnalyzedDuplicates: $hasAnalyzedDuplicates');
  print('🔍 duplicateVideosCount: $duplicateVideosCount');
  print('🔍 isAnalyzingDuplicates: $isAnalyzingDuplicates');
  
  // Check if the widget is being rendered at all
  WidgetsBinding.instance.addPostFrameCallback((_) {
    print('🔍 DEBUG: Post frame callback executed');
    final RenderObject? renderObject = _duplicateCardKey.currentContext?.findRenderObject();
    if (renderObject != null) {
      print('🔍 DEBUG: Render object exists with size: ${renderObject.semanticBounds.size}');
    } else {
      print('🔍 DEBUG: Render object is NULL - widget might not be in the tree');
    }
  });
}

Widget _buildDuplicateVideosCard() {
  return GestureDetector(
    onTap: () => _handleDuplicateVideosCardTap(),
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
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAnalyzingDuplicates ? 'Analyzing Duplicate Videos...' : 'Duplicate Videos',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAnalyzingDuplicates 
                        ? 'Progress: ${(_duplicateVideosAnalysisProgress * 100).toInt()}%'
                        : hasAnalyzedDuplicates && duplicateVideosCount > 0
                          ? '$duplicateVideosCount duplicate videos • ${duplicateVideosSize.toStringAsFixed(1)}GB'
                          : hasAnalyzedDuplicates 
                            ? 'No duplicate videos found'
                            : 'Tap to find duplicate videos',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (isAnalyzingDuplicates)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                  ),
                )
              else
                Text(
                  duplicateVideosCount.toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.red,
                  ),
                ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: Colors.grey,
                size: 20,
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Progress bar when analyzing
          if (isAnalyzingDuplicates) ...[
            LinearProgressIndicator(
              value: _duplicateVideosAnalysisProgress,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
            ),
            const SizedBox(height: 12),
          ],
          
          Container(
            height: 80,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: isAnalyzingDuplicates 
              ? Center(
                  child: Text(
                    'Analyzing for duplicate videos...',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                )
              : (hasAnalyzedDuplicates && duplicateVideosCount > 0)
                ? _buildDuplicateVideosContent()
                : Center(
                    child: Text(
                      hasAnalyzedDuplicates 
                        ? 'No duplicate videos found.'
                        : 'Tap to find duplicate videos.',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}

// Add this helper function if you don't already have it
String _formatDuration(int seconds) {
  return '${seconds}s';
}

Future<void> _handleDuplicateVideosCardTap() async {
  print('🎬 DUPLICATE VIDEOS UI: Card tapped');
  
  if (hasAnalyzedDuplicates && duplicateVideosCount > 0) {
    if (duplicateVideoGroups.isEmpty) {
      print("❌ No duplicate groups available");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No duplicate videos found'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Add debug logs
    print('📊 Navigating to duplicate videos screen with ${duplicateVideoGroups.length} groups');
    
    // Convert DuplicateVideoGroup to VideoGroup
    List<VideoGroup> convertedGroups = await VideoConverter.fromDuplicateGroups(duplicateVideoGroups);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DuplicateVideosScreen(
          duplicateGroups: convertedGroups.map((group) => group.videos).toList(),
          totalCount: duplicateVideosCount,
          totalSize: duplicateVideosSize.toStringAsFixed(1) + " GB",
        ),
      ),
    ).then((result) {
      if (result == true) {
        print('🔄 Duplicates were deleted, refreshing duplicates only...');
        refreshVideoData(analysisType: 'duplicates');
      }
    });
  } else if (!isAnalyzingDuplicates) {
    print('🔍 Starting duplicate analysis...');
    _startDuplicateVideosAnalysis();
  }
}

Widget _buildDuplicateVideosContent() {
  return Row(
    children: [
      // Show sample duplicate videos
      ...duplicateVideoSamples.take(3).map((video) {
        return Expanded(
        child: Container(
  margin: const EdgeInsets.all(4),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(6),
    border: Border.all(color: Colors.red.withOpacity(0.3), width: 2),
  ),
  child: Stack(
    fit: StackFit.expand,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Builder(
          builder: (context) {
            final imageProvider = ThumbnailCache.getCachedImageProvider('thumb_${video.id}');
            if (imageProvider != null) {
              return AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 300),
                child: Image(
                  image: imageProvider,
                  fit: BoxFit.cover,
                  height: double.infinity,
                  width: double.infinity,
                ),
              );
            } else {
              return FutureBuilder<Uint8List?>(
                future: ThumbnailCache.getThumbnail('thumb_${video.id}'),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                          ),
                        ),
                      ),
                    );
                  } else if (snapshot.hasData && snapshot.data != null) {
                    return AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        height: double.infinity,
                        width: double.infinity,
                        cacheWidth: 200,
                      ),
                    );
                  } else {
                    return Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.videocam, color: Colors.grey),
                      ),
                    );
                  }
                },
              );
            }
          },
        ),
      ),
      // Duration indicator (keep as is)
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
            '${video.duration}s',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      // Play icon (keep as is)
      Center(
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.play_arrow,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    ],
  ),
)
,
        );
      }).toList(),

      // Fill remaining space if less than 3 duplicate videos (keep as is)
      ...List.generate(
        3 - duplicateVideoSamples.length,
        (index) => Expanded(
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    ],
  );
}

  // ===== SCREEN RECORDINGS CARD =====
  
  Widget _buildScreenRecordingsCard() {
    return GestureDetector(
      onTap: () async {
        print('🎬 SCREEN RECORDINGS UI: Card tapped');
        
        if (hasAnalyzedScreenRecordings && screenRecordingsCount > 0) {
          // Navigate to Screen Recordings screen
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ScreenRecordingsScreen(
                screenRecordings: allScreenRecordings,
                totalCount: screenRecordingsCount,
                totalSize: screenRecordingsSize,
              ),
            ),
          );
          
          if (result == true) {
            print('🔄 Screen recordings were deleted, refreshing screen recordings only...');
            await refreshVideoData(analysisType: 'screenRecordings');
          }
        } else if (hasAnalyzedScreenRecordings && screenRecordingsCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No screen recordings found! 🎉'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (!isAnalyzingScreenRecordings) {
          print('🎬 Starting screen recordings analysis...');
          _startScreenRecordingsAnalysis();
        }
      },
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
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAnalyzingScreenRecordings ? 'Analyzing Screen Recordings...' : 'Screen Recordings',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAnalyzingScreenRecordings 
                          ? 'Progress: ${(_screenRecordingsAnalysisProgress * 100).toInt()}%'
                          : hasAnalyzedScreenRecordings && screenRecordingsCount > 0
                            ? '$screenRecordingsCount screen recordings • ${screenRecordingsSize.toStringAsFixed(1)}GB'
                            : hasAnalyzedScreenRecordings 
                              ? 'No screen recordings found'
                              : 'Tap to find screen recordings',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAnalyzingScreenRecordings)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  )
                else
                  Text(
                    screenRecordingsCount.toString(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue,
                    ),
                  ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.grey,
                  size: 20,
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Progress bar when analyzing
            if (isAnalyzingScreenRecordings) ...[
              LinearProgressIndicator(
                value: _screenRecordingsAnalysisProgress,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              const SizedBox(height: 12),
            ],
            
            Container(
              height: 80,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: isAnalyzingScreenRecordings 
                ? Center(
                    child: Text(
                      'Analyzing for screen recordings...',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  )
                : (hasAnalyzedScreenRecordings && screenRecordingsCount > 0)
                  ? _buildScreenRecordingsContent()
                  : Center(
                      child: Text(
                        hasAnalyzedScreenRecordings 
                          ? 'No screen recordings found.'
                          : 'Tap to find screen recordings.',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenRecordingsContent() {
    return Row(
      children: [
        // Show sample screen recordings
        ...screenRecordingSamples.take(3).map((video) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: FutureBuilder<Uint8List?>(
                      future: video.thumbnailDataWithSize(
                        const ThumbnailSize(200, 200),
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          return Image.memory(
                            snapshot.data!,
                            fit: BoxFit.cover,
                            height: double.infinity,
                            width: double.infinity,
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
                  // Duration indicator
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
                        '${video.duration}s',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Play icon
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
        
        // Fill remaining space if less than 3 screen recordings
        ...List.generate(
          3 - screenRecordingSamples.length,
          (index) => Expanded(
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===== SHORT VIDEOS CARD =====
  
  Widget _buildShortVideosCard() {
    return GestureDetector(
      onTap: () async {
        print('🎬 SHORT VIDEOS UI: Card tapped');
        
        if (hasAnalyzedShortVideos && shortVideosCount > 0) {
          // Navigate to Short Videos screen
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ShortVideosScreen(
                shortVideos: allShortVideos,
                totalCount: shortVideosCount,
                totalSize: shortVideosSize,
              ),
            ),
          );
          
          if (result == true) {
            print('🔄 Short videos were deleted, refreshing short videos only...');
            await refreshVideoData(analysisType: 'shortVideos');
          }
        } else if (hasAnalyzedShortVideos && shortVideosCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No short videos found! 🎉'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (!isAnalyzingShortVideos) {
          print('🎬 Starting short videos analysis...');
          _startShortVideosAnalysis();
        }
      },
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
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAnalyzingShortVideos ? 'Analyzing Short Videos...' : 'Short Videos',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAnalyzingShortVideos 
                          ? 'Progress: ${(_shortVideosAnalysisProgress * 100).toInt()}%'
                          : hasAnalyzedShortVideos && shortVideosCount > 0
                            ? '$shortVideosCount short videos • ${shortVideosSize.toStringAsFixed(1)}GB'
                            : hasAnalyzedShortVideos 
                              ? 'No short videos found'
                              : 'Tap to find short videos (< 10s)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAnalyzingShortVideos)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  )
                else
                  Text(
                    shortVideosCount.toString(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.green,
                    ),
                  ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.grey,
                  size: 20,
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Progress bar when analyzing
            if (isAnalyzingShortVideos) ...[
              LinearProgressIndicator(
                value: _shortVideosAnalysisProgress,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              ),
              const SizedBox(height: 12),
            ],
            
            Container(
              height: 80,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: isAnalyzingShortVideos 
                ? Center(
                    child: Text(
                      'Analyzing for short videos...',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  )
                : (hasAnalyzedShortVideos && shortVideosCount > 0)
                  ? _buildShortVideosContent()
                  : Center(
                      child: Text(
                        hasAnalyzedShortVideos 
                          ? 'No short videos found.'
                          : 'Tap to find short videos.',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortVideosContent() {
    return Row(
      children: [
        // Show sample short videos
        ...shortVideoSamples.take(3).map((video) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green.withOpacity(0.3), width: 2),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: FutureBuilder<Uint8List?>(
                      future: video.thumbnailDataWithSize(
                        const ThumbnailSize(200, 200),
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          return Image.memory(
                            snapshot.data!,
                            fit: BoxFit.cover,
                            height: double.infinity,
                            width: double.infinity,
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
                  // Duration indicator
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
                        '${video.duration}s',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Play icon
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
        
        // Fill remaining space if less than 3 short videos
        ...List.generate(
          3 - shortVideoSamples.length,
          (index) => Expanded(
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      height: 80,
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(Icons.cleaning_services, 'Cleaning', true),
          _buildNavItem(Icons.speed, 'Boost', false),
          _buildNavItem(Icons.compress, 'Compress', false),
          _buildNavItem(Icons.lock, 'Secret Space', false),
          _buildNavItem(Icons.more_horiz, 'More', false),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: isActive ? Colors.blue : Colors.grey,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.blue : Colors.grey,
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
  _receivePort?.close();
  _duplicateDetectionIsolate?.kill(priority: Isolate.immediate);
  super.dispose();
  }
}


// Define a class to hold the results of the duplicate analysis
class DuplicateAnalysisResult {
  final List<DuplicateVideoGroup> groups;
  final int totalCount;
  final double totalSize;
  
  DuplicateAnalysisResult({
    required this.groups,
    required this.totalCount,
    required this.totalSize,
  });
}