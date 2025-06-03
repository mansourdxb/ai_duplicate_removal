import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'smart_cleaning_screen.dart';
import '../screens/similar_photos_screen.dart';
import '../models/similar_photo_group.dart'; // ✅ Keep this one
import 'dart:typed_data'; // ✅ Keep this one
import '../models/duplicate_photo_group.dart'; 
import 'duplicate_photos_screen.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../screens/screenshots_screen.dart';
import 'package:image/image.dart' as img;
import 'dart:math' as math;
import '../screens/blurry_photos_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  List<SimilarPhotoGroup> similarPhotoGroups = [];
  bool isLoading = false; // Add this for the refresh loading state
// Add this missing variable
double _duplicatePhotosAnalysisProgress = 0.0;

// Screenshot detection variables
List<AssetEntity> allScreenshots = [];
List<AssetEntity> screenshotSamples = [];
int screenshotsCount = 0;
double screenshotsSize = 0.0;
bool isAnalyzingScreenshots = false;
bool hasAnalyzedScreenshots = false;
double _screenshotsAnalysisProgress = 0.0;



  // State variables
  bool isScanning = false;
  bool hasStoragePermission = false;
  bool isLoadingStorage = true;
  
  // UPDATED: Similar photos analysis variables
  bool isAnalyzingSimilar = false;
  bool hasAnalyzedSimilar = false;
  int similarPhotosCount = 0;
  double similarPhotosSize = 0.0; // in MB
  List<AssetEntity> allSimilarPhotos = []; // NEW: Store ALL similar photos
  List<AssetEntity> similarPhotoSamples = []; // Store sample photos for display
  
  // Storage info - Make these dynamic
  double usedStorageGB = 103.0;
  double totalStorageGB = 256.0;
  
  // Tab controller
  int selectedTab = 0;
  
// Duplicate photos analysis variables
bool isAnalyzingDuplicates = false;
bool hasAnalyzedDuplicates = false;
int duplicatePhotosCount = 0;
double duplicatePhotosSize = 0.0;
List<DuplicatePhotoGroup> duplicatePhotoGroups = [];
List<AssetEntity> duplicatePhotoSamples = [];


// Blurry photos analysis
List<AssetEntity> allBlurryPhotos = [];
List<AssetEntity> blurryPhotoSamples = [];
int blurryPhotosCount = 0;
double blurryPhotosSize = 0.0;
bool isAnalyzingBlurry = false;
bool hasAnalyzedBlurry = false;
double _blurryPhotosAnalysisProgress = 0.0;


// ✅ ADD this method to your _HomeScreenState class:

Future<void> _startBlurryPhotosAnalysis() async {
  if (isAnalyzingBlurry) {
    print('🔍 Blurry analysis already in progress');
    return;
  }

  print('🔍 Starting blurry photos analysis...');
  
  setState(() {
    isAnalyzingBlurry = true;
    hasAnalyzedBlurry = false;
    _blurryPhotosAnalysisProgress = 0.0;
    allBlurryPhotos.clear();
    blurryPhotoSamples.clear();
    blurryPhotosCount = 0;
    blurryPhotosSize = 0.0;
  });

  try {
    // Get all photos
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) {
      print('❌ Permission denied for blurry analysis');
      setState(() {
        isAnalyzingBlurry = false;
      });
      return;
    }

    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );

    if (albums.isEmpty) {
      print('📷 No albums found for blurry analysis');
      setState(() {
        isAnalyzingBlurry = false;
        hasAnalyzedBlurry = true;
      });
      return;
    }

    final AssetPathEntity allPhotosAlbum = albums.first;
    final int totalPhotoCount = await allPhotosAlbum.assetCountAsync;
    
    if (totalPhotoCount == 0) {
      print('📷 No photos found for blurry analysis');
      setState(() {
        isAnalyzingBlurry = false;
        hasAnalyzedBlurry = true;
      });
      return;
    }

    print('🔍 Found $totalPhotoCount photos to analyze for blur');

    List<AssetEntity> detectedBlurryPhotos = [];
    const int batchSize = 50;
    int processedCount = 0;

    // Process photos in batches
    for (int i = 0; i < totalPhotoCount; i += batchSize) {
      if (!isAnalyzingBlurry) break; // Stop if analysis was cancelled
      
      final int end = (i + batchSize < totalPhotoCount) ? i + batchSize : totalPhotoCount;
      final List<AssetEntity> batch = await allPhotosAlbum.getAssetListRange(start: i, end: end);
      
      for (final AssetEntity photo in batch) {
        if (!isAnalyzingBlurry) break;
        
        try {
          // Check if photo is blurry
          final bool isBlurry = await _isPhotoBlurry(photo);
          
          if (isBlurry) {
            detectedBlurryPhotos.add(photo);
            print('🔍 Found blurry photo: ${photo.id}');
          }
          
          processedCount++;
          
          // Update progress
          if (mounted) {
            setState(() {
              _blurryPhotosAnalysisProgress = processedCount / totalPhotoCount;
            });
          }
          
        } catch (e) {
          print('❌ Error analyzing photo ${photo.id} for blur: $e');
        }
      }
      
      // Small delay to prevent UI blocking
      await Future.delayed(const Duration(milliseconds: 10));
    }

    if (mounted && isAnalyzingBlurry) {
  // Calculate total size using estimation (faster approach)
double totalSize = 0.0;
for (final photo in detectedBlurryPhotos) {
  int totalPixels = photo.width * photo.height;
  double estimatedMB;
  
  if (totalPixels < 1000000) {
    estimatedMB = 0.5;
  } else if (totalPixels < 3000000) {
    estimatedMB = 1.5;
  } else if (totalPixels < 8000000) {
    estimatedMB = 3.0;
  } else if (totalPixels < 20000000) {
    estimatedMB = 6.0;
  } else {
    estimatedMB = 12.0;
  }
  
  totalSize += estimatedMB * 1024 * 1024; // Convert MB to bytes
}



      setState(() {
        allBlurryPhotos = detectedBlurryPhotos;
        blurryPhotosCount = detectedBlurryPhotos.length;
        blurryPhotosSize = totalSize;
        blurryPhotoSamples = detectedBlurryPhotos.take(6).toList();
        isAnalyzingBlurry = false;
        hasAnalyzedBlurry = true;
        _blurryPhotosAnalysisProgress = 1.0;
      });

      print('✅ Blurry analysis complete: ${detectedBlurryPhotos.length} blurry photos found');
      print('📊 Total size: ${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB');
    }

  } catch (e) {
    print('❌ Error during blurry photos analysis: $e');
    if (mounted) {
      setState(() {
        isAnalyzingBlurry = false;
        hasAnalyzedBlurry = true;
      });
    }
  }
}

// Method to detect if a photo is blurry
Future<bool> _isPhotoBlurry(AssetEntity photo) async {
  try {
    // Get image data with reduced size for faster processing
    final Uint8List? imageData = await photo.thumbnailDataWithSize(
      const ThumbnailSize(400, 400), // Smaller size for faster processing
      quality: 80,
    );
    
    if (imageData == null) return false;
    
    // Decode image
    final img.Image? image = img.decodeImage(imageData);
    if (image == null) return false;
    
    // Calculate blur score using Laplacian variance
    final double blurScore = _calculateLaplacianVariance(image);
    
    // Threshold for blur detection (lower = more blurry)
    // You can adjust this value based on testing
    const double blurThreshold = 100.0;
    
    final bool isBlurry = blurScore < blurThreshold;
    
    if (isBlurry) {
      print('🔍 Blur score: ${blurScore.toStringAsFixed(2)} (threshold: $blurThreshold)');
    }
    
    return isBlurry;
    
  } catch (e) {
    print('❌ Error checking blur for photo ${photo.id}: $e');
    return false;
  }
}

// Calculate Laplacian variance to detect blur
double _calculateLaplacianVariance(img.Image image) {
  // Convert to grayscale for better blur detection
  final img.Image grayscale = img.grayscale(image);
  
  // Laplacian kernel for edge detection
  final List<List<int>> laplacianKernel = [
    [0, -1, 0],
    [-1, 4, -1],
    [0, -1, 0],
  ];
  
  List<double> laplacianValues = [];
  
  // Apply Laplacian filter (skip borders)
  for (int y = 1; y < grayscale.height - 1; y++) {
    for (int x = 1; x < grayscale.width - 1; x++) {
      double sum = 0.0;
      
      for (int ky = 0; ky < 3; ky++) {
        for (int kx = 0; kx < 3; kx++) {
          final pixel = grayscale.getPixel(x + kx - 1, y + ky - 1);
          final intensity = img.getLuminance(pixel);
          sum += intensity * laplacianKernel[ky][kx];
        }
      }
      
      laplacianValues.add(sum.abs());
    }
  }
  
  if (laplacianValues.isEmpty) return 0.0;
  
  // Calculate variance
  final double mean = laplacianValues.reduce((a, b) => a + b) / laplacianValues.length;
  final double variance = laplacianValues
      .map((value) => math.pow(value - mean, 2))
      .reduce((a, b) => a + b) / laplacianValues.length;
  
  return variance;
}


void _debugRebuildUI() {
  print('🔄 Debug: Forcing UI rebuild');
  setState(() {
    // Force rebuild
  });
}

Future<void> _startScreenshotsAnalysis() async {
  print('📱 STARTING screenshots analysis...');
  
  if (isAnalyzingScreenshots) {
    print('⚠️ Screenshots analysis already running, skipping...');
    return;
  }
  
  setState(() {
    isAnalyzingScreenshots = true;
    _screenshotsAnalysisProgress = 0.0;
  });

  try {
    // Request photo manager permission
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.hasAccess) {
      setState(() {
        isAnalyzingScreenshots = false;
      });
      return;
    }

    // Get all image assets
    print('📱 Getting photos to analyze for screenshots...');
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );

    if (paths.isNotEmpty) {
      final AssetPathEntity allPhotos = paths.first;
      final List<AssetEntity> assets = await allPhotos.getAssetListRange(
        start: 0,
        end: await allPhotos.assetCountAsync,
      );
      
      print('📊 Found ${assets.length} photos to analyze for screenshots');
      
      if (assets.isEmpty) {
        setState(() {
          _screenshotsAnalysisProgress = 1.0;
          isAnalyzingScreenshots = false;
          hasAnalyzedScreenshots = true;
        });
        return;
      }

      // Find screenshots
      List<AssetEntity> screenshots = await _findScreenshots(assets);
      
      // Calculate total size of screenshots
      double totalSizeGB = await _calculateEstimatedSize(screenshots);
      
      // Get sample screenshots for display (first 3)
      List<AssetEntity> samples = screenshots.take(3).toList();

      setState(() {
        allScreenshots = screenshots;
        screenshotsCount = screenshots.length;
        screenshotsSize = totalSizeGB;
        screenshotSamples = samples;
        _screenshotsAnalysisProgress = 1.0;
        isAnalyzingScreenshots = false;
        hasAnalyzedScreenshots = true;
      });

      print('✅ SCREENSHOTS: Analysis complete - ${screenshots.length} screenshots found');

    } else {
      setState(() {
        isAnalyzingScreenshots = false;
        hasAnalyzedScreenshots = true;
        _screenshotsAnalysisProgress = 1.0;
      });
    }
  } catch (e) {
    print('❌ Error analyzing screenshots: $e');
    setState(() {
      isAnalyzingScreenshots = false;
      hasAnalyzedScreenshots = true;
      _screenshotsAnalysisProgress = 1.0;
    });
  }
}


Future<List<AssetEntity>> _findScreenshots(List<AssetEntity> assets) async {
  List<AssetEntity> screenshots = [];
  
  for (int i = 0; i < assets.length; i++) {
    final asset = assets[i];
    
    // Update progress
    if (i % 100 == 0) {
      setState(() {
        _screenshotsAnalysisProgress = i / assets.length;
      });
    }
    
    try {
      // Check if it's a screenshot based on multiple criteria
      bool isScreenshot = await _isScreenshot(asset);
      
      if (isScreenshot) {
        screenshots.add(asset);
       // print('📱 Found screenshot: ${asset.title}');
      }
      
    } catch (e) {
      print('❌ Error checking screenshot for ${asset.id}: $e');
    }
  }
  
  return screenshots;
}



Future<bool> _isScreenshot(AssetEntity asset) async {
  try {
    // Method 1: Check filename patterns
    String? title = asset.title;
    if (title != null) {
      String lowerTitle = title.toLowerCase();
      
      // Common screenshot filename patterns
      List<String> screenshotPatterns = [
        'screenshot',
        'screen_shot',
        'screen-shot',
        'scrnshot',
        'capture',
        'screen_capture',
        'screen-capture',
      ];
      
      for (String pattern in screenshotPatterns) {
        if (lowerTitle.contains(pattern)) {
         // print('📱 Screenshot detected by filename: $title');
          return true;
        }
      }
      
      // Android screenshot pattern: Screenshot_YYYYMMDD-HHMMSS
      RegExp androidPattern = RegExp(r'screenshot_\d{8}-\d{6}');
      if (androidPattern.hasMatch(lowerTitle)) {
        //print('📱 Screenshot detected by Android pattern: $title');
        return true;
      }
      
      // iOS screenshot pattern: IMG_XXXX (but need to check dimensions)
      if (lowerTitle.startsWith('img_') && lowerTitle.endsWith('.png')) {
        // Check if dimensions match common screen resolutions
        if (await _hasScreenshotDimensions(asset)) {
          //print('📱 Screenshot detected by iOS pattern + dimensions: $title');
          return true;
        }
      }
    }
    
    // Method 2: Check if it's from Screenshots folder/album
    // This is harder to detect reliably across different devices
    
    // Method 3: Check creation time patterns (screenshots often taken in quick succession)
    // This could be implemented but might have false positives
    
    return false;
    
  } catch (e) {
    print('❌ Error in screenshot detection: $e');
    return false;
  }
}

Future<bool> _hasScreenshotDimensions(AssetEntity asset) async {
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
    
    // Check for common aspect ratios that might be screenshots
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
    print('❌ Error checking screenshot dimensions: $e');
    return false;
  }
}


Widget _buildScreenshotsCard() {
  return GestureDetector(
    // ✅ UPDATE your screenshots card onTap:
onTap: () async {
  print('📱 SCREENSHOTS UI: Card tapped');
  
  if (hasAnalyzedScreenshots && screenshotsCount > 0) {
    // Navigate to Screenshots screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScreenshotsScreen(
          screenshots: allScreenshots,
          totalCount: screenshotsCount,
          totalSize: screenshotsSize,
        ),
      ),
    );
    
    if (result == true) {
      print('🔄 Screenshots were deleted, refreshing screenshots only...');
      await refreshPhotoData(analysisType: 'screenshots'); // ✅ Only screenshots
    }
  } else if (hasAnalyzedScreenshots && screenshotsCount == 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No screenshots found! 🎉'),
        backgroundColor: Colors.green,
      ),
    );
  } else if (!isAnalyzingScreenshots) {
    print('📱 Starting screenshots analysis...');
    _startScreenshotsAnalysis();
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
                      isAnalyzingScreenshots ? 'Analyzing Screenshots...' : 'Screenshots',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAnalyzingScreenshots 
                        ? 'Progress: ${(_screenshotsAnalysisProgress * 100).toInt()}%'
                        : hasAnalyzedScreenshots && screenshotsCount > 0
                          ? '$screenshotsCount screenshots • ${screenshotsSize.toStringAsFixed(1)}GB'
                          : hasAnalyzedScreenshots 
                            ? 'No screenshots found'
                            : 'Tap to find screenshots',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (isAnalyzingScreenshots)
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
                  screenshotsCount.toString(),
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
          if (isAnalyzingScreenshots) ...[
            LinearProgressIndicator(
              value: _screenshotsAnalysisProgress,
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
            child: isAnalyzingScreenshots 
              ? Center(
                  child: Text(
                    'Analyzing for screenshots...',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                )
              : (hasAnalyzedScreenshots && screenshotsCount > 0)
                ? _buildScreenshotsContent()
                : Center(
                    child: Text(
                      hasAnalyzedScreenshots 
                        ? 'No screenshots found.'
                        : 'Tap to find screenshots.',
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

Widget _buildScreenshotsContent() {
  return Row(
    children: [
      // Show sample screenshots
      ...screenshotSamples.take(3).map((screenshot) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: FutureBuilder<Uint8List?>(
                future: screenshot.thumbnailDataWithSize(
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
                      child: Icon(Icons.image, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      }).toList(),
      
      // Fill remaining space if less than 3 screenshots
      ...List.generate(
        3 - screenshotSamples.length,
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


String _getDuplicateStatusText() {
  if (isAnalyzingDuplicates) {
    return 'Analyzing photos...';
  } else if (hasAnalyzedDuplicates) {
    if (duplicatePhotosCount > 0) {
      return 'Found $duplicatePhotosCount duplicate photos';
    } else {
      return 'No duplicates found';
    }
  } else {
    return 'Tap to find duplicate photos';
  }
}

// Start duplicate analysis
Future<void> _startDuplicatePhotosAnalysis() async {
  print('🚀 STARTING duplicate analysis...');
  
  if (isAnalyzingDuplicates) {
    print('⚠️ Analysis already running, skipping...');
    return;
  }
  
  setState(() {
    isAnalyzingDuplicates = true;
    _duplicatePhotosAnalysisProgress = 0.0;
  });

  try {
    // Request photo manager permission
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.hasAccess) {
      setState(() {
        isAnalyzingDuplicates = false;
      });
      return;
    }

    // Get all image assets - LIMIT TO 1000 FOR TESTING
    print('📱 Getting photos (limited to 1000 for testing)...');
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );

    if (paths.isNotEmpty) {
      final AssetPathEntity allPhotos = paths.first;
      
      // LIMIT TO FIRST 1000 PHOTOS FOR TESTING
      final List<AssetEntity> assets = await allPhotos.getAssetListRange(
        start: 0,
        end: 1000, // Test with fewer photos first
      );
      
      print('📊 Found ${assets.length} photos to analyze');
      
      if (assets.isEmpty) {
        setState(() {
          _duplicatePhotosAnalysisProgress = 1.0;
          isAnalyzingDuplicates = false;
          hasAnalyzedDuplicates = true;
        });
        return;
      }

      // Find duplicate photos
      List<DuplicatePhotoGroup> groups = await _findAndGroupDuplicatePhotosFixed(assets);
      
      // Extract all duplicate photos from groups
      List<AssetEntity> allDuplicatePhotosList = [];
      for (var group in groups) {
        allDuplicatePhotosList.addAll(group.duplicatesToDelete);
      }
      
      // Calculate total size of duplicate photos
      double totalSizeGB = await _calculateEstimatedSize(allDuplicatePhotosList);
      
      // Get sample photos for display
      List<AssetEntity> samples = [];
      for (var group in groups) {
        for (int i = 1; i < group.photos.length && samples.length < 3; i++) {
          samples.add(group.photos[i]);
        }
      }

      setState(() {
        duplicatePhotoGroups = groups;
        duplicatePhotosCount = allDuplicatePhotosList.length;
        duplicatePhotosSize = totalSizeGB;
        duplicatePhotoSamples = samples;
        _duplicatePhotosAnalysisProgress = 1.0;
        isAnalyzingDuplicates = false;
        hasAnalyzedDuplicates = true;
      });

      print('✅ DUPLICATE: Analysis complete - ${groups.length} groups with ${allDuplicatePhotosList.length} total duplicates');

    } else {
      setState(() {
        isAnalyzingDuplicates = false;
        hasAnalyzedDuplicates = true;
        _duplicatePhotosAnalysisProgress = 1.0;
      });
    }
  } catch (e) {
    print('❌ Error analyzing duplicate photos: $e');
    setState(() {
      isAnalyzingDuplicates = false;
      hasAnalyzedDuplicates = true;
      _duplicatePhotosAnalysisProgress = 1.0;
    });
  }
}

// Main duplicate detection algorithm using multiple approaches

// Add this helper method to verify duplicates
Future<bool> _verifyDuplicates(List<AssetEntity> photos) async {
  if (photos.length < 2) return false;
  
  try {
    // Get the first photo's properties as reference
    AssetEntity reference = photos.first;
    int refWidth = reference.width;
    int refHeight = reference.height;
    
    // Check if all photos have same dimensions
    for (int i = 1; i < photos.length; i++) {
      AssetEntity photo = photos[i];
      if (photo.width != refWidth || photo.height != refHeight) {
        print('🔍 DUPLICATE: Different dimensions - not duplicates');
        return false;
      }
    }
    
    // If same size AND same dimensions AND taken within short time frame, likely duplicates
    DateTime refTime = reference.createDateTime;
    for (int i = 1; i < photos.length; i++) {
      DateTime photoTime = photos[i].createDateTime;
      Duration timeDiff = photoTime.difference(refTime).abs();
      
      // Allow up to 10 seconds difference (for burst photos or quick succession)
      if (timeDiff.inSeconds > 10) {
        print('🔍 DUPLICATE: Time difference too large (${timeDiff.inSeconds}s) - not duplicates');
        return false;
      }
    }
    
    print('✅ DUPLICATE: Verified as duplicates - same size, dimensions, and time');
    return true;
    
  } catch (e) {
    print('❌ DUPLICATE: Error verifying duplicates: $e');
    return false;
  }
}

// Add this new method
Future<List<DuplicatePhotoGroup>> _findAndGroupDuplicatePhotosFixed(List<AssetEntity> allPhotos) async {
  print('🔍 IDENTICAL: Starting FAST identical detection of ${allPhotos.length} photos');
  
  List<DuplicatePhotoGroup> groups = [];
  
  try {
    // FASTER approach: Use file size + dimensions + filename
    Map<String, List<AssetEntity>> signatureGroups = {};
    
    for (int i = 0; i < allPhotos.length; i++) {
      var photo = allPhotos[i];
      
      try {
        // Create signature without reading file content (much faster)
        String signature = "${photo.width}x${photo.height}_${photo.title ?? 'unknown'}_${photo.modifiedDateTime?.millisecondsSinceEpoch ?? 0}";
        
        signatureGroups.putIfAbsent(signature, () => []).add(photo);
        
        // Update progress every 100 photos
        if (i % 100 == 0) {
          print('Processed ${i + 1}/${allPhotos.length}');
          
          // Update UI progress
          if (mounted) {
            setState(() {
              _duplicatePhotosAnalysisProgress = (i + 1) / allPhotos.length;
            });
          }
        }
        
      } catch (e) {
        continue;
      }
    }
    
    print('🔍 IDENTICAL: Created ${signatureGroups.length} unique signatures');
    
    // Find groups with multiple photos
    for (var entry in signatureGroups.entries) {
      if (entry.value.length > 1) {
        List<AssetEntity> duplicates = entry.value;
        
        print('✅ IDENTICAL: Found ${duplicates.length} identical photos');
        
        // Sort by creation time
        duplicates.sort((a, b) {
          if (a.createDateTime == null && b.createDateTime == null) return 0;
          if (a.createDateTime == null) return 1;
          if (b.createDateTime == null) return -1;
          return a.createDateTime!.compareTo(b.createDateTime!);
        });
        
        // Estimate size (much faster than reading files)
        double estimatedSize = (duplicates.length - 1) * 0.003; // 3MB per photo estimate
        
        DuplicatePhotoGroup group = DuplicatePhotoGroup(
          photos: duplicates,
          originalIndex: 0,
          selectedIndices: Set.from(List.generate(duplicates.length - 1, (i) => i + 1)),
          duplicateType: 'Identical',
          groupId: 'fast_${DateTime.now().millisecondsSinceEpoch}_${groups.length}',
          totalSize: estimatedSize,
          confidence: 0.95,
        );
        
        groups.add(group);
      }
    }
    
    print('✅ IDENTICAL: Found ${groups.length} groups of identical photos');
    return groups;
    
  } catch (e) {
    print('❌ IDENTICAL: Error: $e');
    return [];
  }
}

// Method to compute file hash for identical detection
Future<String?> _computePhotoHash(AssetEntity photo) async {
  try {
    // Get file data
    File? file = await photo.file;
    if (file == null) return null;
    
    // Read file bytes
    List<int> bytes = await file.readAsBytes();
    
    // Compute MD5 hash of file content
    var digest = md5.convert(bytes);
    return digest.toString();
    
  } catch (e) {
    print('Error computing hash for ${photo.id}: $e');
    return null;
  }
}

// Helper method to calculate group size
Future<double> _calculateGroupSize(List<AssetEntity> photos, {bool excludeFirst = false}) async {
  double totalSize = 0.0;
  int startIndex = excludeFirst ? 1 : 0;
  
  for (int i = startIndex; i < photos.length; i++) {
    var photo = photos[i];
    int totalPixels = photo.width * photo.height;
    
    // Estimate file size based on resolution
    double estimatedMB;
    if (totalPixels < 1000000) {
      estimatedMB = 0.5; // Low res
    } else if (totalPixels < 3000000) {
      estimatedMB = 1.5; // Medium res
    } else if (totalPixels < 8000000) {
      estimatedMB = 3.0; // High res
    } else if (totalPixels < 20000000) {
      estimatedMB = 6.0; // Very high res
    } else {
      estimatedMB = 12.0; // Ultra high res
    }
    
    totalSize += estimatedMB;
  }
  
  return totalSize / 1024; // Convert MB to GB
}

// Helper method to group photos by creation time
Future<List<List<AssetEntity>>> _groupByCreationTime(List<AssetEntity> photos) async {
  List<List<AssetEntity>> timeGroups = [];
  
  for (var photo in photos) {
    if (photo.createDateTime == null) continue;
    
    bool addedToGroup = false;
    
    // Try to add to existing time group (within 60 seconds)
    for (var timeGroup in timeGroups) {
      if (timeGroup.isNotEmpty && timeGroup.first.createDateTime != null) {
        Duration timeDiff = photo.createDateTime!.difference(timeGroup.first.createDateTime!).abs();
        
        if (timeDiff.inSeconds <= 60) { // Within 1 minute
          timeGroup.add(photo);
          addedToGroup = true;
          break;
        }
      }
    }
    
    // Create new time group if not added to existing
    if (!addedToGroup) {
      timeGroups.add([photo]);
    }
  }
  
  return timeGroups;
}

// Enhanced verification method
Future<bool> _verifyRealDuplicates(List<AssetEntity> photos) async {
  if (photos.length < 2) return false;
  
  try {
    // Get reference photo properties
    AssetEntity reference = photos.first;
    int refWidth = reference.width;
    int refHeight = reference.height;
    DateTime? refTime = reference.createDateTime;
    
    print('🔍 DUPLICATE: Verifying ${photos.length} photos against reference:');
    print('  - Dimensions: ${refWidth}x${refHeight}');
    print('  - Time: $refTime');
    
    // Check each photo against reference
    for (int i = 1; i < photos.length; i++) {
      AssetEntity photo = photos[i];
      
      // Must have exact same dimensions
      if (photo.width != refWidth || photo.height != refHeight) {
        print('❌ DUPLICATE: Different dimensions - not duplicates');
        return false;
      }
      
      // Must be taken within reasonable time frame
      if (refTime != null && photo.createDateTime != null) {
        Duration timeDiff = photo.createDateTime!.difference(refTime).abs();
        if (timeDiff.inMinutes > 5) { // Max 5 minutes apart
          print('❌ DUPLICATE: Time difference too large (${timeDiff.inMinutes} minutes) - not duplicates');
          return false;
        }
      }
    }
    
    print('✅ DUPLICATE: Verified as true duplicates');
    return true;
    
  } catch (e) {
    print('❌ DUPLICATE: Error verifying duplicates: $e');
    return false;
  }
}

// Algorithm 1: Find exact duplicates (same file size and dimensions) [[2]](#__2)
Future<void> _findExactDuplicates(
  List<AssetEntity> allPhotos, 
  List<DuplicatePhotoGroup> groups, 
  Set<String> processedPhotoIds
) async {
  Map<String, List<AssetEntity>> exactMatches = {};
  
  for (var photo in allPhotos) {
    if (processedPhotoIds.contains(photo.id)) continue;
    
    // Create unique key based on dimensions
    String key = "${photo.width}x${photo.height}";
    
    if (!exactMatches.containsKey(key)) {
      exactMatches[key] = [];
    }
    exactMatches[key]!.add(photo);
  }
  
  int groupIndex = 0;
  for (var entry in exactMatches.entries) {
    if (entry.value.length >= 2) {
      // Sort by creation date to keep the oldest as original
      entry.value.sort((a, b) {
        if (a.createDateTime == null && b.createDateTime == null) return 0;
        if (a.createDateTime == null) return 1;
        if (b.createDateTime == null) return -1;
        return a.createDateTime!.compareTo(b.createDateTime!);
      });
      
      // Calculate total size
      double totalSize = 0.0;
      for (var photo in entry.value) {
        int pixels = photo.width * photo.height;
        double estimatedMB = _estimatePhotoSizeForDuplicates(pixels);
        totalSize += estimatedMB;
      }
      totalSize = totalSize / 1024; // Convert to GB
      
      groups.add(DuplicatePhotoGroup(
        photos: entry.value,
        originalIndex: 0, // Keep the first (oldest)
        selectedIndices: Set.from(Iterable.generate(entry.value.length - 1, (i) => i + 1)),
        duplicateType: 'exact',
        groupId: 'exact_$groupIndex',
        totalSize: totalSize,
        confidence: 1.0, // Highest confidence
      ));
      
      // Mark as processed
      for (var photo in entry.value) {
        processedPhotoIds.add(photo.id);
      }
      groupIndex++;
    }
  }
  
  print('🎯 Found ${groupIndex} exact duplicate groups');
}

// Algorithm 2: Find near-exact duplicates (same dimensions, close timestamps) [[1]](#__1)
Future<void> _findNearExactDuplicates(
  List<AssetEntity> allPhotos, 
  List<DuplicatePhotoGroup> groups, 
  Set<String> processedPhotoIds
) async {
  Map<String, List<AssetEntity>> nearMatches = {};
  
  for (var photo in allPhotos) {
    if (processedPhotoIds.contains(photo.id) || photo.createDateTime == null) continue;
    
    // Group by dimensions and hour
    String hourKey = "${photo.width}x${photo.height}_${photo.createDateTime!.year}-${photo.createDateTime!.month}-${photo.createDateTime!.day}-${photo.createDateTime!.hour}";
    
    if (!nearMatches.containsKey(hourKey)) {
      nearMatches[hourKey] = [];
    }
    nearMatches[hourKey]!.add(photo);
  }
  
  int groupIndex = 0;
  for (var entry in nearMatches.entries) {
    if (entry.value.length >= 2) {
      // Further filter by close timestamps (within 10 minutes)
      List<List<AssetEntity>> timeGroups = [];
      
      for (var photo in entry.value) {
        bool addedToGroup = false;
        
        for (var timeGroup in timeGroups) {
          if (timeGroup.isNotEmpty) {
            Duration diff = photo.createDateTime!.difference(timeGroup.first.createDateTime!).abs();
            if (diff.inMinutes <= 10) {
              timeGroup.add(photo);
              addedToGroup = true;
              break;
            }
          }
        }
        
        if (!addedToGroup) {
          timeGroups.add([photo]);
        }
      }
      
      // Add groups with 2+ photos
      for (var timeGroup in timeGroups) {
        if (timeGroup.length >= 2) {
          // Sort by file size (keep largest as original)
          timeGroup.sort((a, b) {
            int aPixels = a.width * a.height;
            int bPixels = b.width * b.height;
            return bPixels.compareTo(aPixels);
          });
          
          double totalSize = 0.0;
          for (var photo in timeGroup) {
            int pixels = photo.width * photo.height;
            double estimatedMB = _estimatePhotoSizeForDuplicates(pixels);
            totalSize += estimatedMB;
          }
          totalSize = totalSize / 1024;
          
          groups.add(DuplicatePhotoGroup(
            photos: timeGroup,
            originalIndex: 0, // Keep the largest
            selectedIndices: Set.from(Iterable.generate(timeGroup.length - 1, (i) => i + 1)),
            duplicateType: 'near_exact',
            groupId: 'near_exact_$groupIndex',
            totalSize: totalSize,
            confidence: 0.9, // High confidence
          ));
          
          for (var photo in timeGroup) {
            processedPhotoIds.add(photo.id);
          }
          groupIndex++;
        }
      }
    }
  }
  
  print('🎯 Found ${groupIndex} near-exact duplicate groups');
}

// Algorithm 3: Find resolution variants (same aspect ratio, different resolutions) [[3]](#__3)
Future<void> _findResolutionVariants(
  List<AssetEntity> allPhotos, 
  List<DuplicatePhotoGroup> groups, 
  Set<String> processedPhotoIds
) async {
  Map<String, List<AssetEntity>> aspectGroups = {};
  
  for (var photo in allPhotos) {
    if (processedPhotoIds.contains(photo.id)) continue;
    
    double aspectRatio = photo.width / photo.height;
    String aspectKey = (aspectRatio * 100).round().toString(); // Round to avoid floating point issues
    
    if (!aspectGroups.containsKey(aspectKey)) {
      aspectGroups[aspectKey] = [];
    }
    aspectGroups[aspectKey]!.add(photo);
  }
  
  int groupIndex = 0;
  for (var entry in aspectGroups.entries) {
    if (entry.value.length >= 2) {
      // Group by creation time (within same day)
      Map<String, List<AssetEntity>> dayGroups = {};
      
      for (var photo in entry.value) {
        if (photo.createDateTime != null) {
          String dayKey = "${photo.createDateTime!.year}-${photo.createDateTime!.month}-${photo.createDateTime!.day}";
          
          if (!dayGroups.containsKey(dayKey)) {
            dayGroups[dayKey] = [];
          }
          dayGroups[dayKey]!.add(photo);
        }
      }
      
      for (var dayGroup in dayGroups.values) {
        if (dayGroup.length >= 2) {
          // Sort by resolution (keep highest resolution)
          dayGroup.sort((a, b) {
            int aPixels = a.width * a.height;
            int bPixels = b.width * b.height;
            return bPixels.compareTo(aPixels);
          });
          
          double totalSize = 0.0;
          for (var photo in dayGroup) {
            int pixels = photo.width * photo.height;
            double estimatedMB = _estimatePhotoSizeForDuplicates(pixels);
            totalSize += estimatedMB;
          }
          totalSize = totalSize / 1024;
          
          groups.add(DuplicatePhotoGroup(
            photos: dayGroup,
            originalIndex: 0, // Keep highest resolution
            selectedIndices: Set.from(Iterable.generate(dayGroup.length - 1, (i) => i + 1)),
            duplicateType: 'resolution_variant',
            groupId: 'resolution_$groupIndex',
            totalSize: totalSize,
            confidence: 0.7, // Medium confidence
          ));
          
          for (var photo in dayGroup) {
            processedPhotoIds.add(photo.id);
          }
          groupIndex++;
        }
      }
    }
  }
  
  print('🎯 Found ${groupIndex} resolution variant groups');
}

// Algorithm 4: Find filename pattern duplicates [[0]](#__0)
Future<void> _findFilenameDuplicates(
  List<AssetEntity> allPhotos, 
  List<DuplicatePhotoGroup> groups, 
  Set<String> processedPhotoIds
) async {
  Map<String, List<AssetEntity>> filenameGroups = {};
  
  for (var photo in allPhotos) {
    if (processedPhotoIds.contains(photo.id)) continue;
    
    String? title = photo.title;
    if (title != null && title.isNotEmpty) {
      // Remove common suffixes and extensions
      String baseFilename = title
          .replaceAll(RegExp(r'_\d+\.(jpg|jpeg|png|gif)$', caseSensitive: false), '')
          .replaceAll(RegExp(r'\.(jpg|jpeg|png|gif)$', caseSensitive: false), '')
          .replaceAll(RegExp(r'_copy\d*$', caseSensitive: false), '')
          .replaceAll(RegExp(r'_duplicate\d*$', caseSensitive: false), '');
      
      if (baseFilename.length >= 5) { // Only consider meaningful filenames
        if (!filenameGroups.containsKey(baseFilename)) {
          filenameGroups[baseFilename] = [];
        }
        filenameGroups[baseFilename]!.add(photo);
      }
    }
  }
  
  int groupIndex = 0;
  for (var entry in filenameGroups.entries) {
    if (entry.value.length >= 2) {
      // Sort by creation date (keep oldest)
      entry.value.sort((a, b) {
        if (a.createDateTime == null && b.createDateTime == null) return 0;
        if (a.createDateTime == null) return 1;
        if (b.createDateTime == null) return -1;
        return a.createDateTime!.compareTo(b.createDateTime!);
      });
      
      double totalSize = 0.0;
      for (var photo in entry.value) {
        int pixels = photo.width * photo.height;
        double estimatedMB = _estimatePhotoSizeForDuplicates(pixels);
        totalSize += estimatedMB;
      }
      totalSize = totalSize / 1024;
      
      groups.add(DuplicatePhotoGroup(
        photos: entry.value,
        originalIndex: 0, // Keep oldest
        selectedIndices: Set.from(Iterable.generate(entry.value.length - 1, (i) => i + 1)),
        duplicateType: 'filename_pattern',
        groupId: 'filename_$groupIndex',
        totalSize: totalSize,
        confidence: 0.6, // Lower confidence
      ));
      
      for (var photo in entry.value) {
        processedPhotoIds.add(photo.id);
      }
      groupIndex++;
    }
  }
  
  print('🎯 Found ${groupIndex} filename pattern duplicate groups');
}

// Helper method for size estimation
double _estimatePhotoSizeForDuplicates(int pixels) {
  if (pixels < 1000000) return 0.5;
  else if (pixels < 3000000) return 1.5;
  else if (pixels < 8000000) return 3.0;
  else if (pixels < 20000000) return 6.0;
  else return 12.0;
}


@override
void initState() {
  super.initState();
  _initializeAnimations();
  _checkPermissions();
  _getStorageInfo();
  
  // Start all analyses after the widget is built
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _startSimilarPhotosAnalysis();
    _startDuplicatePhotosAnalysis();
    _startScreenshotsAnalysis();
    _startBlurryPhotosAnalysis(); // ✅ Add this line
  });
}
  // Add this method to your _HomeScreenState class
  Future<void> _debugPhotoAnalysis() async {
    print('=== HOME SCREEN PHOTO DEBUG ===');
    
    try {
      // Request photo manager permission
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (!ps.hasAccess) {
        print('❌ No photo access permission');
        return;
      }

      // Get all image assets - SAME METHOD as your analysis
      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );

      if (paths.isNotEmpty) {
        final AssetPathEntity allPhotos = paths.first;
        final int totalCount = await allPhotos.assetCountAsync;
        print('📊 Total photos from PhotoManager: $totalCount');
        
        // Get actual assets
        final List<AssetEntity> assets = await allPhotos.getAssetListRange(
          start: 0,
          end: totalCount,
        );
        
        print('📊 Actually loaded assets: ${assets.length}');
        
        // Analyze what types of photos we have
        Map<String, int> typeCount = {};
        Map<String, int> sizeCount = {};
        int nullPathCount = 0;
        int validPhotos = 0;
        
        for (var asset in assets) {
          // Count by type
          String type = asset.type.toString();
          typeCount[type] = (typeCount[type] ?? 0) + 1;
          
          // Count by size category
          int pixels = asset.width * asset.height;
          String sizeCategory;
          if (pixels < 100000) sizeCategory = 'tiny';
          else if (pixels < 1000000) sizeCategory = 'small';
          else if (pixels < 3000000) sizeCategory = 'medium';
          else if (pixels < 8000000) sizeCategory = 'large';
          else sizeCategory = 'huge';
          
          sizeCount[sizeCategory] = (sizeCount[sizeCategory] ?? 0) + 1;
          
          // Check for null paths
          if (asset.relativePath == null) {
            nullPathCount++;
          } else {
            validPhotos++;
          }
        }
        
        print('📊 Photo types: $typeCount');
        print('📊 Size categories: $sizeCount');
        print('📊 Photos with null path: $nullPathCount');
        print('📊 Photos with valid path: $validPhotos');
        
        // Test your grouping logic
        print('\n🔍 Testing grouping logic...');
        List<SimilarPhotoGroup> groups = await _findAndGroupSimilarPhotos(assets);
        
        int totalPhotosInGroups = 0;
        for (var group in groups) {
          totalPhotosInGroups += group.photos.length;
         // print('   Group "${group.reason}": ${group.photos.length} photos');
        }
        
        print('📊 Total photos in groups: $totalPhotosInGroups');
        print('📊 Photos not in any group: ${assets.length - totalPhotosInGroups}');
        
        // ADD THIS NEW SECTION at the end:
        print('\n🔍 Testing what gets passed to Similar Photos Screen...');
        
        if (similarPhotoGroups.isNotEmpty) {
          int totalInGroups = 0;
          for (var group in similarPhotoGroups) {
            totalInGroups += group.photos.length;
          }
          print('📊 Photos in similarPhotoGroups: $totalInGroups');
          print('📊 Photos in allSimilarPhotos: ${allSimilarPhotos.length}');
          print('📊 Photos in similarPhotosCount: $similarPhotosCount');
          
          // Check if allSimilarPhotos matches the groups
          Set<String> groupPhotoIds = {};
          for (var group in similarPhotoGroups) {
            for (var photo in group.photos) {
              groupPhotoIds.add(photo.id);
            }
          }
          
          Set<String> allSimilarPhotoIds = allSimilarPhotos.map((p) => p.id).toSet();
          
          print('📊 Unique photos in groups: ${groupPhotoIds.length}');
          print('📊 Unique photos in allSimilarPhotos: ${allSimilarPhotoIds.length}');
          
          // Find differences
          final inGroupsNotInAll = groupPhotoIds.difference(allSimilarPhotoIds);
          final inAllNotInGroups = allSimilarPhotoIds.difference(groupPhotoIds);
          
          if (inGroupsNotInAll.isNotEmpty) {
            print('⚠️  Photos in groups but not in allSimilarPhotos: ${inGroupsNotInAll.length}');
          }
          if (inAllNotInGroups.isNotEmpty) {
            print('⚠️  Photos in allSimilarPhotos but not in groups: ${inAllNotInGroups.length}');
          }
        }
        
      } else {
        print('❌ No photo paths found');
      }
      
    } catch (e) {
      print('❌ Error in debug analysis: $e');
    }
    
    print('=== END HOME SCREEN DEBUG ===\n');
  }

// ✅ REPLACE your refreshPhotoData method with this selective version:
Future<void> refreshPhotoData({String? analysisType}) async {
  print('🔄 Refreshing photo data after deletion for: ${analysisType ?? "all"}');
  
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
        _startSimilarPhotosAnalysis();
        _startDuplicatePhotosAnalysis();
        _startScreenshotsAnalysis();
      });
      
      _showRefreshMessage('All analyses restarted!');
      
    } else if (analysisType == 'screenshots') {
      // Only clear screenshots data
      setState(() {
        allScreenshots.clear();
        screenshotSamples.clear();
        screenshotsCount = 0;
        screenshotsSize = 0.0;
        _screenshotsAnalysisProgress = 0.0;
        isAnalyzingScreenshots = false;
        hasAnalyzedScreenshots = false;
        isLoading = false;
      });
      
      // Only restart screenshots analysis
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startScreenshotsAnalysis();
      });
      
      _showRefreshMessage('Screenshots re-analyzing...');
      
    } else if (analysisType == 'similar') {
      // Only clear similar photos data
      setState(() {
        similarPhotoGroups.clear();
        allSimilarPhotos.clear();
        similarPhotoSamples.clear();
        similarPhotosCount = 0;
        similarPhotosSize = 0.0;
        isAnalyzingSimilar = false;
        hasAnalyzedSimilar = false;
        isLoading = false;
      });
      
      // Only restart similar photos analysis
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startSimilarPhotosAnalysis();
      });
      
      _showRefreshMessage('Similar photos re-analyzing...');
      
    } else if (analysisType == 'duplicates') {
      // Only clear duplicates data
      setState(() {
        duplicatePhotoGroups.clear();
        duplicatePhotoSamples.clear();
        duplicatePhotosCount = 0;
        duplicatePhotosSize = 0.0;
        _duplicatePhotosAnalysisProgress = 0.0;
        isAnalyzingDuplicates = false;
        hasAnalyzedDuplicates = false;
        isLoading = false;
      });
      
      // Only restart duplicates analysis
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startDuplicatePhotosAnalysis();
      });
      
      _showRefreshMessage('Duplicates re-analyzing...');
    }
    else if (analysisType == 'blurry') {
  // Only clear blurry photos data
  setState(() {
    allBlurryPhotos.clear();
    blurryPhotoSamples.clear();
    blurryPhotosCount = 0;
    blurryPhotosSize = 0.0;
    _blurryPhotosAnalysisProgress = 0.0;
    isAnalyzingBlurry = false;
    hasAnalyzedBlurry = false;
    isLoading = false;
  });
  
  // Only restart blurry photos analysis
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _startBlurryPhotosAnalysis();
  });
  
  _showRefreshMessage('Blurry photos re-analyzing...');
}

  } catch (e) {
    print('❌ Error refreshing photo data: $e');
    setState(() {
      isLoading = false;
    });
  }
}

// Helper method to clear all analysis data
void _clearAllAnalysisData() {
  // Clear duplicate data
  duplicatePhotoGroups.clear();
  duplicatePhotoSamples.clear();
  duplicatePhotosCount = 0;
  duplicatePhotosSize = 0.0;
  _duplicatePhotosAnalysisProgress = 0.0;
  isAnalyzingDuplicates = false;
  hasAnalyzedDuplicates = false;
  
  // Clear similar photos
  similarPhotoGroups.clear();
  allSimilarPhotos.clear();
  similarPhotoSamples.clear();
  similarPhotosCount = 0;
  similarPhotosSize = 0.0;
  isAnalyzingSimilar = false;
  hasAnalyzedSimilar = false;
  
  // Clear screenshots data
  allScreenshots.clear();
  screenshotSamples.clear();
  screenshotsCount = 0;
  screenshotsSize = 0.0;
  _screenshotsAnalysisProgress = 0.0;
  isAnalyzingScreenshots = false;
  hasAnalyzedScreenshots = false;

  // Clear blurry photos data
allBlurryPhotos.clear();
blurryPhotoSamples.clear();
blurryPhotosCount = 0;
blurryPhotosSize = 0.0;
_blurryPhotosAnalysisProgress = 0.0;
isAnalyzingBlurry = false;
hasAnalyzedBlurry = false;
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

Widget _buildDuplicatePhotosCard() {
  return GestureDetector(
   // ✅ UPDATE your duplicates card onTap:
onTap: () async {
  print('🔍 DUPLICATE UI: Card tapped');
  
  if (hasAnalyzedDuplicates && duplicatePhotosCount > 0) {
    if (duplicatePhotoGroups.isEmpty) {
      print("❌ No duplicate groups available");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please analyze photos first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    List<SimilarPhotoGroup> convertedGroups = duplicatePhotoGroups.map((duplicateGroup) {
      return SimilarPhotoGroup(
        photos: duplicateGroup.photos,
        bestPhotoIndex: duplicateGroup.originalIndex,
        selectedIndices: duplicateGroup.selectedIndices,
        reason: 'Duplicate: ${duplicateGroup.duplicateType}',
        groupId: duplicateGroup.groupId,
        totalSize: duplicateGroup.totalSize,
      );
    }).toList();
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DuplicatePhotosScreen(
          preGroupedPhotos: convertedGroups,
          totalCount: duplicatePhotosCount,
          totalSize: duplicatePhotosSize,
        ),
      ),
    );
    
    if (result == true) {
      print('🔄 Duplicates were deleted, refreshing duplicates only...');
      await refreshPhotoData(analysisType: 'duplicates'); // ✅ Only duplicates
    }
  } else if (!isAnalyzingDuplicates) {
    print('🔍 Starting duplicate analysis...');
    _startDuplicatePhotosAnalysis();
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
                      isAnalyzingDuplicates ? 'Analyzing Duplicates...' : 'Duplicate',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAnalyzingDuplicates 
                        ? 'Progress: ${(_duplicatePhotosAnalysisProgress * 100).toInt()}%'
                        : hasAnalyzedDuplicates && duplicatePhotosCount > 0
                          ? '$duplicatePhotosCount photos in ${duplicatePhotoGroups.length} groups • ${duplicatePhotosSize.toStringAsFixed(1)}GB'
                          : hasAnalyzedDuplicates 
                            ? 'No duplicates found'
                            : 'Tap to find duplicates',
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
                  duplicatePhotosCount.toString(),
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
          
          // Add progress bar when analyzing
          if (isAnalyzingDuplicates) ...[
            LinearProgressIndicator(
              value: _duplicatePhotosAnalysisProgress,
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
                    'Analyzing ${(_duplicatePhotosAnalysisProgress * 1000).toInt()}/1000 photos...',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                )
              : (hasAnalyzedDuplicates && duplicatePhotosCount > 0)
                ? _buildDuplicatePhotosContent()
                : Center(
                    child: Text(
                      hasAnalyzedDuplicates 
                        ? 'No duplicates found.'
                        : 'Tap to analyze for duplicates.',
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

Widget _buildDuplicatePhotosContent() {
  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: Row(
      children: [
        // Show sample photos
        ...duplicatePhotoSamples.take(3).map((photo) => 
          Container(
            width: 60,
            height: 60,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[300],
              border: Border.all(color: Colors.red.withOpacity(0.3), width: 2),
            ),
            child: FutureBuilder<Uint8List?>(
              future: photo.thumbnailData,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(
                      snapshot.data!,
                      fit: BoxFit.cover,
                      width: 56,
                      height: 56,
                    ),
                  );
                }
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(6),
                  ),
                );
              },
            ),
          ),
        ).toList(),
        
        // Show count if more photos
        if (duplicatePhotosCount > 3)
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Center(
              child: Text(
                '+${duplicatePhotosCount - 3}',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    ),
  );
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

  // Update your size calculation method:
  Future<double> _calculateEstimatedSize(List<AssetEntity> photos) async {
    double totalSize = 0.0;
    
    for (var photo in photos) {
      // Estimate file size based on resolution and format
      int totalPixels = photo.width * photo.height;
      double estimatedMB;
      
      // Estimate based on typical compression ratios
      if (totalPixels < 1000000) {
        estimatedMB = 0.5; // Low res photos
      } else if (totalPixels < 3000000) {
        estimatedMB = 1.5; // Medium res photos
      } else if (totalPixels < 8000000) {
        estimatedMB = 3.0; // High res photos
      } else if (totalPixels < 20000000) {
        estimatedMB = 6.0; // Very high res photos
      } else {
        estimatedMB = 12.0; // Ultra high res photos
      }
      
      totalSize += estimatedMB;
    }
    
    return totalSize / 1024; // Convert MB to GB
  }

  void _checkPermissions() async {
    try {
      final status = await Permission.storage.status;
      if (mounted) {
        setState(() {
          hasStoragePermission = status.isGranted;
        });
      }
    } catch (e) {
      print('Error checking permissions: $e');
      if (mounted) {
        setState(() {
          hasStoragePermission = false;
        });
      }
    }
  }

  void _requestPermissions() async {
    try {
      final status = await Permission.storage.request();
      if (mounted) {
        setState(() {
          hasStoragePermission = status.isGranted;
        });
        
        // If permission granted, restart similar photos analysis
        if (status.isGranted && !hasAnalyzedSimilar) {
          _startSimilarPhotosAnalysis();
        }
      }
    } catch (e) {
      print('Error requesting permissions: $e');
      if (mounted) {
        setState(() {
          hasStoragePermission = false;
        });
      }
    }
  }

  // UPDATED: Real similar photos analysis method with grouping
 Future<void> _startSimilarPhotosAnalysis() async {
  // Add this guard to prevent multiple simultaneous analyses
  if (isAnalyzingSimilar) {
    print('🔍 Similar photos analysis already in progress, skipping...');
    return;
  }
  
  setState(() {
    isAnalyzingSimilar = true;
    hasAnalyzedSimilar = false;
  });
    // ADD THIS DEBUG CALL
    await _debugPhotoAnalysis();

    try {
      // Request photo manager permission
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (!ps.hasAccess) {
        setState(() {
          isAnalyzingSimilar = false;
        });
        return;
      }

      // Get all image assets
      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );

      if (paths.isNotEmpty) {
        final AssetPathEntity allPhotos = paths.first;
        final List<AssetEntity> assets = await allPhotos.getAssetListRange(
          start: 0,
          end: await allPhotos.assetCountAsync,
        );

        // ADD THIS ADDITIONAL DEBUG
        print('🏠 HOME: About to analyze ${assets.length} photos');

        // REAL ANALYSIS: Find actually similar photos and group them
        List<SimilarPhotoGroup> groups = await _findAndGroupSimilarPhotos(assets);
        
        // Extract all similar photos from groups
        List<AssetEntity> allSimilarPhotosList = [];
        for (var group in groups) {
          allSimilarPhotosList.addAll(group.photos);
        }
        
        // Calculate total size of similar photos using the improved method
        double totalSizeGB = await _calculateEstimatedSize(allSimilarPhotosList);
        
        // Get sample photos for display (first 3 similar photos)
        List<AssetEntity> samples = allSimilarPhotosList.take(3).toList();

        setState(() {
          similarPhotoGroups = groups; // Store grouped results
          similarPhotosCount = allSimilarPhotosList.length;
          similarPhotosSize = totalSizeGB;
          allSimilarPhotos = allSimilarPhotosList; // Store ALL similar photos
          similarPhotoSamples = samples;    // Store samples for display
          isAnalyzingSimilar = false;
          hasAnalyzedSimilar = true;
        });
      } else {
        setState(() {
          isAnalyzingSimilar = false;
          hasAnalyzedSimilar = true;
        });
      }
    } catch (e) {
      print('Error analyzing similar photos: $e');
      setState(() {
        isAnalyzingSimilar = false;
        hasAnalyzedSimilar = true;
      });
    }
  }

  // NEW: Method to find and group similar photos
  // IMPROVED: Method to find and group similar photos
Future<List<SimilarPhotoGroup>> _findAndGroupSimilarPhotos(List<AssetEntity> allPhotos) async {
  List<SimilarPhotoGroup> groups = [];
  Set<String> processedPhotoIds = {};
  
  try {
    print('Starting analysis of ${allPhotos.length} photos');
    
    // Group 1: Find burst photos (photos taken within 2 minutes of each other)
    Map<String, List<AssetEntity>> burstGroups = {};
    
    for (var photo in allPhotos) {
      if (photo.createDateTime != null && !processedPhotoIds.contains(photo.id)) {
        int timeSlot = photo.createDateTime!.millisecondsSinceEpoch ~/ 120000;
        String timeKey = timeSlot.toString();
        
        if (!burstGroups.containsKey(timeKey)) {
          burstGroups[timeKey] = [];
        }
        burstGroups[timeKey]!.add(photo);
      }
    }
    
    // Add burst photo groups
    int groupIndex = 0;
    for (var group in burstGroups.values) {
      if (group.length >= 2) {
        // Calculate total size for this group
        double totalSize = 0.0;
        for (var photo in group) {
          int totalPixels = photo.width * photo.height;
          double estimatedMB;
          if (totalPixels < 1000000) {
            estimatedMB = 0.5;
          } else if (totalPixels < 3000000) {
            estimatedMB = 1.5;
          } else if (totalPixels < 8000000) {
            estimatedMB = 3.0;
          } else if (totalPixels < 20000000) {
            estimatedMB = 6.0;
          } else {
            estimatedMB = 12.0;
          }
          totalSize += estimatedMB;
        }
        totalSize = totalSize / 1024; // Convert MB to GB

        groups.add(SimilarPhotoGroup(
          photos: group,
          bestPhotoIndex: 0,
          selectedIndices: group.length > 1
              ? Set.from(Iterable.generate(group.length - 1, (i) => i + 1))
              : <int>{},
          reason: 'Burst photos taken within 2 seconds',
          groupId: 'burst_$groupIndex',
          totalSize: totalSize,
        ));

        // Mark these photos as processed
        for (var photo in group) {
          processedPhotoIds.add(photo.id);
        }
        groupIndex++;
      }
    }
    
    // Group 2: Find photos with similar aspect ratios (excluding already processed)
    Map<String, List<AssetEntity>> dimensionGroups = {};
    
    for (var photo in allPhotos) {
      if (!processedPhotoIds.contains(photo.id)) {
        double aspectRatio = photo.width / photo.height;
        String ratioKey;
        
        if (aspectRatio < 0.8) {
          ratioKey = "portrait";
        } else if (aspectRatio > 1.2) {
          ratioKey = "landscape";
        } else {
          ratioKey = "square";
        }
        
        if (!dimensionGroups.containsKey(ratioKey)) {
          dimensionGroups[ratioKey] = [];
        }
        dimensionGroups[ratioKey]!.add(photo);
      }
    }
    
    // Add aspect ratio groups
    for (var entry in dimensionGroups.entries) {
      if (entry.value.length >= 10) {
        // Calculate total size for this group
        double totalSize = 0.0;
        for (var photo in entry.value) {
          int totalPixels = photo.width * photo.height;
          double estimatedMB;
          if (totalPixels < 1000000) {
            estimatedMB = 0.5;
          } else if (totalPixels < 3000000) {
            estimatedMB = 1.5;
          } else if (totalPixels < 8000000) {
            estimatedMB = 3.0;
          } else if (totalPixels < 20000000) {
            estimatedMB = 6.0;
          } else {
            estimatedMB = 12.0;
          }
          totalSize += estimatedMB;
        }
        totalSize = totalSize / 1024; // Convert MB to GB

        groups.add(SimilarPhotoGroup(
          photos: entry.value,
          bestPhotoIndex: 0,
          selectedIndices: entry.value.length > 1
              ? Set.from(Iterable.generate(entry.value.length - 1, (i) => i + 1))
              : <int>{},
          reason: 'Aspect ratio group: ${entry.key}',
          groupId: 'aspect_${entry.key}',
          totalSize: totalSize,
        ));

        // Mark these photos as processed
        for (var photo in entry.value) {
          processedPhotoIds.add(photo.id);
        }
      }
    }
    
    // Group 3: Find screenshots (excluding already processed)
    List<AssetEntity> screenshots = [];
    
    for (var photo in allPhotos) {
      if (!processedPhotoIds.contains(photo.id)) {
        double ratio = photo.width / photo.height;
        
        bool isLikelyScreenshot = (
          (ratio > 0.4 && ratio < 0.7) ||
          (ratio > 1.4 && ratio < 2.5) ||
          (photo.width == 1080) ||
          (photo.width == 1440) ||
          (photo.width == 750) ||
          (photo.width == 828) ||
          (photo.width == 1125) ||
          (photo.width == 1242)
        );
        
        if (isLikelyScreenshot) {
          screenshots.add(photo);
        }
      }
    }
    
    if (screenshots.length >= 2) {
      // Calculate total size for this group
      double totalSize = 0.0;
      for (var photo in screenshots) {
        int totalPixels = photo.width * photo.height;
        double estimatedMB;
        if (totalPixels < 1000000) {
          estimatedMB = 0.5;
        } else if (totalPixels < 3000000) {
          estimatedMB = 1.5;
        } else if (totalPixels < 8000000) {
          estimatedMB = 3.0;
        } else if (totalPixels < 20000000) {
          estimatedMB = 6.0;
        } else {
          estimatedMB = 12.0;
        }
        totalSize += estimatedMB;
      }
      totalSize = totalSize / 1024; // Convert MB to GB

      groups.add(SimilarPhotoGroup(
        photos: screenshots,
        bestPhotoIndex: 0,
        selectedIndices: screenshots.length > 1
            ? Set.from(Iterable.generate(screenshots.length - 1, (i) => i + 1))
            : <int>{},
        reason: 'Screenshots group',
        groupId: 'screenshots',
        totalSize: totalSize,
      ));

      // Mark these photos as processed
      for (var photo in screenshots) {
        processedPhotoIds.add(photo.id);
      }
    }
    
    // Group 4: Same day photos (excluding already processed)
    Map<String, List<AssetEntity>> dayGroups = {};
    
    for (var photo in allPhotos) {
      if (photo.createDateTime != null && !processedPhotoIds.contains(photo.id)) {
        String dayKey = "${photo.createDateTime!.year}-${photo.createDateTime!.month}-${photo.createDateTime!.day}";
        
        if (!dayGroups.containsKey(dayKey)) {
          dayGroups[dayKey] = [];
        }
        dayGroups[dayKey]!.add(photo);
      }
    }
    
    for (var entry in dayGroups.entries) {
      if (entry.value.length >= 5) {
        // Calculate total size for this group
        double totalSize = 0.0;
        for (var photo in entry.value) {
          int totalPixels = photo.width * photo.height;
          double estimatedMB;
          if (totalPixels < 1000000) {
            estimatedMB = 0.5;
          } else if (totalPixels < 3000000) {
            estimatedMB = 1.5;
          } else if (totalPixels < 8000000) {
            estimatedMB = 3.0;
          } else if (totalPixels < 20000000) {
            estimatedMB = 6.0;
          } else {
            estimatedMB = 12.0;
          }
          totalSize += estimatedMB;
        }
        totalSize = totalSize / 1024; // Convert MB to GB

        groups.add(SimilarPhotoGroup(
          photos: entry.value,
          bestPhotoIndex: 0,
          selectedIndices: entry.value.length > 1
              ? Set.from(Iterable.generate(entry.value.length - 1, (i) => i + 1))
              : <int>{},
          reason: 'Photos taken on the same day: ${entry.key}',
          groupId: 'sameday_${entry.key}',
          totalSize: totalSize,
        ));

        // Mark these photos as processed
        for (var photo in entry.value) {
          processedPhotoIds.add(photo.id);
        }
      }
    }
    
    // Group 5: Photos with similar resolution (excluding already processed)
    Map<String, List<AssetEntity>> resolutionGroups = {};
    
    for (var photo in allPhotos) {
      if (!processedPhotoIds.contains(photo.id)) {
        int totalPixels = photo.width * photo.height;
        String resolutionKey;
        if (totalPixels < 1000000) {
          resolutionKey = "low_res";
        } else if (totalPixels < 3000000) {
          resolutionKey = "medium_res";
        } else if (totalPixels < 8000000) {
          resolutionKey = "high_res";
        } else if (totalPixels < 20000000) {
          resolutionKey = "very_high_res";
        } else {
          resolutionKey = "ultra_high_res";
        }
        
        if (!resolutionGroups.containsKey(resolutionKey)) {
          resolutionGroups[resolutionKey] = [];
        }
        resolutionGroups[resolutionKey]!.add(photo);
      }
    }
    
    for (var entry in resolutionGroups.entries) {
      if (entry.value.length >= 8) {
        // Calculate total size for this group
        double totalSize = 0.0;
        for (var photo in entry.value) {
          int totalPixels = photo.width * photo.height;
          double estimatedMB;
          if (totalPixels < 1000000) {
            estimatedMB = 0.5;
          } else if (totalPixels < 3000000) {
            estimatedMB = 1.5;
          } else if (totalPixels < 8000000) {
            estimatedMB = 3.0;
          } else if (totalPixels < 20000000) {
            estimatedMB = 6.0;
          } else {
            estimatedMB = 12.0;
          }
          totalSize += estimatedMB;
        }
        totalSize = totalSize / 1024; // Convert MB to GB

        groups.add(SimilarPhotoGroup(
          photos: entry.value,
          bestPhotoIndex: 0,
          selectedIndices: entry.value.length > 1
              ? Set.from(Iterable.generate(entry.value.length - 1, (i) => i + 1))
              : <int>{},
          reason: 'Same resolution: ${entry.key}',
          groupId: 'resolution_${entry.key}',
          totalSize: totalSize,
        ));

        // Mark these photos as processed
        for (var photo in entry.value) {
          processedPhotoIds.add(photo.id);
        }
      }
    }
    
    // Sort groups by number of photos (largest first)
    groups.sort((a, b) => b.photos.length.compareTo(a.photos.length));
    
    int totalPhotosInGroups = groups.fold(0, (sum, group) => sum + group.photos.length);
    print('Created ${groups.length} similar photo groups with $totalPhotosInGroups total photos');
    
    return groups;
    
  } catch (e) {
    print('Error in _findAndGroupSimilarPhotos: $e');
    return [];
  }
}
  // Keep your existing _findSimilarPhotos method for backward compatibility
  Future<List<AssetEntity>> _findSimilarPhotos(List<AssetEntity> allPhotos) async {
    // Your existing implementation...
    // This is now used as a fallback if needed
    return [];
  }

  void _getStorageInfo() async {
    try {
      if (Platform.isAndroid) {
        await _getAndroidStorageInfo();
      } else if (Platform.isIOS) {
        await _getIOSStorageInfo();
      }
    } catch (e) {
      print('Error getting storage info: $e');
      setState(() {
        isLoadingStorage = false;
      });
    }
  }

  Future<void> _getAndroidStorageInfo() async {
    try {
      final ProcessResult result = await Process.run('df', ['/data']);
      final lines = result.stdout.toString().split('\n');
      
      if (lines.length > 1) {
        final parts = lines[1].split(RegExp(r'\s+'));
        if (parts.length >= 4) {
          final totalKB = double.tryParse(parts[1]) ?? 0;
          final usedKB = double.tryParse(parts[2]) ?? 0;
          
          setState(() {
            totalStorageGB = totalKB / (1024 * 1024);
            usedStorageGB = usedKB / (1024 * 1024);
            isLoadingStorage = false;
          });
          
          _updateProgressAnimation();
          return;
        }
      }
      
      setState(() {
        isLoadingStorage = false;
      });
    } catch (e) {
      print('Android storage error: $e');
      setState(() {
        isLoadingStorage = false;
      });
    }
  }

  Future<void> _getIOSStorageInfo() async {
    try {
      setState(() {
        totalStorageGB = 256.0;
        usedStorageGB = 103.0;
        isLoadingStorage = false;
      });
      _updateProgressAnimation();
    } catch (e) {
      print('iOS storage error: $e');
      setState(() {
        isLoadingStorage = false;
      });
    }
  }

  void _updateProgressAnimation() {
    final progressValue = usedStorageGB / totalStorageGB;
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: progressValue,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
    
    _progressController.reset();
    _progressController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.settings, color: Colors.blue, size: 20),
          onPressed: () {
            // Navigate to settings
          },
        ),
        title: const Text(
          'AI Cleaner',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00D4AA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.workspace_premium, color: Colors.white, size: 12),
                SizedBox(width: 2),
                Text(
                  'PRO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStorageCard(),
            const SizedBox(height: 20),
            _buildSmartCleanButton(),
            const SizedBox(height: 20),
            _buildTabSelector(),
            const SizedBox(height: 16),
            _buildAnalysisCards(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildStorageCard() {
    final percentage = ((usedStorageGB / totalStorageGB) * 100).round();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enhance your phone\'s\nperformance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isLoadingStorage 
              ? 'Loading storage info...'
              : 'Used:${usedStorageGB.toInt()}GB of ${totalStorageGB.toInt()}GB',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 6,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.transparent),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, child) {
                        return SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            value: _progressAnimation.value,
                            strokeWidth: 6,
                            backgroundColor: Colors.transparent,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                            strokeCap: StrokeCap.round,
                          ),
                        );
                      },
                    ),
                    Center(
                      child: Text(
                        '$percentage%',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmartCleanButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SmartCleaningScreen(),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Smart Clean Now',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.auto_fix_high, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => selectedTab = 0),
              child: Container(
                decoration: BoxDecoration(
                  color: selectedTab == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: selectedTab == 0 ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ] : null,
                ),
                child: Center(
                  child: Text(
                    'Photos',
                    style: TextStyle(
                      color: selectedTab == 0 ? Colors.blue : Colors.grey[600],
                      fontWeight: selectedTab == 0 ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => selectedTab = 1),
              child: Container(
                decoration: BoxDecoration(
                  color: selectedTab == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: selectedTab == 1 ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ] : null,
                ),
                child: Center(
                  child: Text(
                    'Videos',
                    style: TextStyle(
                      color: selectedTab == 1 ? Colors.blue : Colors.grey[600],
                      fontWeight: selectedTab == 1 ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

Widget _buildBlurryPhotosCard() {
  return GestureDetector(
    onTap: () async {
      print('📸 BLURRY UI: Card tapped');
      
      if (hasAnalyzedBlurry && blurryPhotosCount > 0) {
        // Navigate to Blurry photos screen
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BlurryPhotosScreen(
              blurryPhotos: allBlurryPhotos,
              totalCount: blurryPhotosCount,
              totalSize: blurryPhotosSize / (1024 * 1024 * 1024), // Convert bytes to GB
            ),
          ),
        );
        
        if (result == true) {
          print('🔄 Blurry photos were deleted, refreshing blurry only...');
          await refreshPhotoData(analysisType: 'blurry');
        }
      } else if (hasAnalyzedBlurry && blurryPhotosCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No blurry photos found! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (!isAnalyzingBlurry) {
        print('📸 Starting blurry photos analysis...');
        _startBlurryPhotosAnalysis();
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
                      isAnalyzingBlurry ? 'Analyzing Blurry Photos...' : 'Blurry',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAnalyzingBlurry 
                        ? 'Progress: ${(_blurryPhotosAnalysisProgress * 100).toInt()}%'
                        : hasAnalyzedBlurry && blurryPhotosCount > 0
                          ? '$blurryPhotosCount photos • ${(blurryPhotosSize / (1024 * 1024)).toStringAsFixed(1)}MB'
                          : hasAnalyzedBlurry 
                            ? 'No blurry photos found'
                            : 'Tap to find blurry photos',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (isAnalyzingBlurry)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                )
              else
                Text(
                  blurryPhotosCount.toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.orange,
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
          if (isAnalyzingBlurry) ...[
            LinearProgressIndicator(
              value: _blurryPhotosAnalysisProgress,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
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
            child: isAnalyzingBlurry 
              ? Center(
                  child: Text(
                    'Analyzing for blurry photos...',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                )
              : (hasAnalyzedBlurry && blurryPhotosCount > 0)
                ? _buildBlurryPhotosContent()
                : Center(
                    child: Text(
                      hasAnalyzedBlurry 
                        ? 'No blurry photos found.'
                        : 'Tap to find blurry photos.',
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

Widget _buildBlurryPhotosContent() {
  return Row(
    children: [
      // Show sample blurry photos
      ...blurryPhotoSamples.take(3).map((photo) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FutureBuilder<Uint8List?>(
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
                  // Blur overlay indicator
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.blur_on,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
      
      // Fill remaining space if less than 3 blurry photos
      ...List.generate(
        3 - blurryPhotoSamples.length,
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

  Widget _buildAnalysisCards() {
  return Column(
    children: [
      // Enhanced Similar Photos Card with final results
      _buildSimilarPhotosCard(),
      
      const SizedBox(height: 12),
      
      _buildDuplicatePhotosCard(),
      
      const SizedBox(height: 12),
      
      _buildScreenshotsCard(), // ✅ Your custom screenshots card
      
      const SizedBox(height: 12),
      
      _buildBlurryPhotosCard(), // ✅ Add custom blurry photos card

      
      //const SizedBox(height: 20),
      
    // _buildPermissionCard(),
    ],
  );
}

  // UPDATED: Enhanced Similar Photos Card with navigation to grouped photos
  Widget _buildSimilarPhotosCard() {
    return GestureDetector(
   // ✅ UPDATE your similar photos card onTap:
onTap: () async {
  if (hasAnalyzedSimilar && similarPhotosCount > 0) {
    if (similarPhotoGroups.isEmpty) {
      print("❌ No groups available - run analysis first");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please analyze photos first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute
      (
        builder: (context) => SimilarPhotosScreen(
          preGroupedPhotos: similarPhotoGroups,
          totalCount: similarPhotosCount,       
          totalSize: similarPhotosSize,
        ),
      ),
    );
    
    if (result == true) {
      print('🔄 Similar photos were deleted, refreshing similar only...');
      await refreshPhotoData(analysisType: 'similar'); // ✅ Only similar photos
    }
  } else if (!isAnalyzingSimilar) {
    print('🔍 Starting similar photos analysis...');
    _startSimilarPhotosAnalysis();
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
                        isAnalyzingSimilar ? 'Analyzing Similar Photos...' : 'Similar',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAnalyzingSimilar 
                          ? 'Scanning...' 
                          : hasAnalyzedSimilar && similarPhotosCount > 0
                            ? '$similarPhotosCount photos in ${similarPhotoGroups.length} groups • ${similarPhotosSize.toStringAsFixed(1)}GB'
                            : '0.0GB',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAnalyzingSimilar)
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
                    similarPhotosCount.toString(),
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
            
            Container(
              height: 80,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: isAnalyzingSimilar 
                ? Center(
                    child: Text(
                      'Analyzing...',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  )
                : (hasAnalyzedSimilar && similarPhotosCount > 0)
                  ? _buildSimilarPhotosContent()
                  : Center(
                      child: Text(
                        'Nothing to clean here.',
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

  Widget _buildSimilarPhotosContent() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          // Show sample photos
          ...similarPhotoSamples.take(3).map((photo) => 
            Container(
              width: 60,
              height: 60,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[300],
              ),
              child: FutureBuilder<Uint8List?>(
                future: photo.thumbnailData,
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        width: 60,
                        height: 60,
                      ),
                    );
                  }
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                  );
                },
              ),
            ),
          ).toList(),
          
          // Show count if more photos
          if (similarPhotosCount > 3)
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Center(
                child: Text(
                  '+${similarPhotosCount - 3}',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnalysisCard({
    required String title,
    required String subtitle,
    required int count,
    bool isAnalyzing = false,
  }) {
    return Container(
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
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
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
          Container(
            height: 60,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                'Nothing to clean here.',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.close,
              size: 24,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'We have limited access to your photos.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    try {
                      await Permission.storage.request();
                    } catch (e) {
                      print('Error requesting permission: $e');
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Open Settings',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _requestPermissions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Grant Permission',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
    super.dispose();
  }
}

// Simple chart painter for the graph - MOVED OUTSIDE THE CLASS
class SimpleChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height * 0.8);
    path.lineTo(size.width * 0.3, size.height * 0.5);
    path.lineTo(size.width * 0.6, size.height * 0.3);
    path.lineTo(size.width, size.height * 0.1);

    canvas.drawPath(path, paint);

    // Draw dots
    final dotPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width, size.height * 0.1), 3, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
