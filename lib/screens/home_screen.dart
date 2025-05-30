import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'smart_cleaning_screen.dart';
import '../screens/similar_photos_screen.dart';
import '../models/similar_photo_group.dart'; // Add this import
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:io';
import 'package:flutter/material.dart';
// Add this line:
import 'package:permission_handler/permission_handler.dart' show openAppSettings;



class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
    List<SimilarPhotoGroup> similarPhotoGroups = [];


  
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
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkPermissions();
    _getStorageInfo();
    // Start similar photos analysis on first launch
    _startSimilarPhotosAnalysis();
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
  void _startSimilarPhotosAnalysis() async {
    if (hasAnalyzedSimilar) return;
    
    setState(() {
      isAnalyzingSimilar = true;
    });

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
  Set<String> processedPhotoIds = {}; // Track processed photos to avoid duplicates
  
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
        groups.add(SimilarPhotoGroup(
          groupId: 'burst_$groupIndex',
          photos: group,
          reason: 'Burst photos taken within 2 minutes',
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
      if (entry.value.length >= 10) { // Increased threshold since we have many photos
        groups.add(SimilarPhotoGroup(
          groupId: 'ratio_${entry.key}',
          photos: entry.value,
          reason: 'Similar aspect ratio (${entry.key})',
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
      groups.add(SimilarPhotoGroup(
        groupId: 'screenshots',
        photos: screenshots,
        reason: 'Likely screenshots',
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
      if (entry.value.length >= 5) { // Increased threshold
        groups.add(SimilarPhotoGroup(
          groupId: 'sameday_${entry.key}',
          photos: entry.value,
          reason: 'Photos from ${entry.key}',
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
      if (entry.value.length >= 8) { // Increased threshold
        groups.add(SimilarPhotoGroup(
          groupId: 'resolution_${entry.key}',
          photos: entry.value,
          reason: 'Similar resolution (${entry.key.replaceAll('_', ' ')})',
        ));
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

  Widget _buildAnalysisCards() {
    return Column(
      children: [
        // Enhanced Similar Photos Card with final results
        _buildSimilarPhotosCard(),
        
        const SizedBox(height: 12),
        
        _buildAnalysisCard(
          title: 'Duplicate',
          subtitle: '0.0KB',
          count: 0,
        ),
        
        const SizedBox(height: 12),
        
        _buildAnalysisCard(
          title: 'Screenshots',
          subtitle: '0.0KB',
          count: 0,
        ),

        const SizedBox(height: 12),
        
        _buildAnalysisCard(
          title: 'Blurry',
          subtitle: '0.0KB',
          count: 0,
        ),
        const SizedBox(height: 20),
        
        _buildPermissionCard(),
      ],
    );
  }

  // UPDATED: Enhanced Similar Photos Card with navigation to grouped photos
  Widget _buildSimilarPhotosCard() {
    return GestureDetector(
      onTap: () {
        if (hasAnalyzedSimilar && similarPhotosCount > 0) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SimilarPhotosScreen(
                similarPhotos: allSimilarPhotos, // Pass ALL similar photos
                totalCount: similarPhotosCount,
                totalSize: similarPhotosSize,
                preGroupedPhotos: similarPhotoGroups, // Pass pre-grouped data
              ),
            ),
          );
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

  // Content widget showing chart and photos
  Widget _buildSimilarPhotosContent() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          // LEFT: Chart/Graph area
          Container(
            width: 80,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Simple chart representation
                Container(
                  width: 40,
                  height: 20,
                  child: CustomPaint(
                    painter: SimpleChartPainter(),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${similarPhotoGroups.length}', // Show number of groups
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 12),
          
          // RIGHT: Photo thumbnails
          Expanded(
            child: Row(
              children: [
                for (int i = 0; i < 3 && i < similarPhotoSamples.length; i++) ...[
                  Expanded(
                    child: Container(
                      height: 64,
                      margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.grey[300],
                      ),
                      child: FutureBuilder<Widget>(
                        future: _buildPhotoThumbnail(similarPhotoSamples[i]),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: snapshot.data!,
                            );
                          }
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.image,
                              color: Colors.grey,
                              size: 24,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build photo thumbnail
  Future<Widget> _buildPhotoThumbnail(AssetEntity asset) async {
    final thumbnail = await asset.thumbnailDataWithSize(
      const ThumbnailSize(200, 200),
    );
    
    if (thumbnail != null) {
      return Image.memory(
        thumbnail,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    
    return Container(
      color: Colors.grey[300],
      child: const Icon(
        Icons.image,
        color: Colors.grey,
        size: 24,
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
          // Try to open app settings
          try {
            await openAppSettings();
          } catch (e) {
            print('Error opening app settings: $e');
            // Fallback: show a dialog with instructions
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Permission Required'),
                content: const Text(
                  'Please go to Settings > Apps > AI Cleaner > Permissions and enable Storage permission.'
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
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
        onPressed: () async {
          // Request permission again
          final status = await Permission.storage.request();
          if (mounted) {
            setState(() {
              hasStoragePermission = status.isGranted;
            });
            
            if (status.isGranted) {
              // Restart the analysis if permission was granted
              _startSimilarPhotosAnalysis();
            }
          }
        },
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
          style: TextStyle(
            fontSize: 14,
          ),
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

// Simple chart painter for the graph
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
