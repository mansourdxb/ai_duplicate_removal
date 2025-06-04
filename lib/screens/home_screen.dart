import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'smart_cleaning_screen.dart';
import '../screens/similar_photos_screen.dart';
import '../models/similar_photo_group.dart'; 
import 'dart:typed_data';
import '../models/duplicate_photo_group.dart'; 
import 'duplicate_photos_screen.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../screens/screenshots_screen.dart';
import 'package:image/image.dart' as img;
import 'dart:math' as math;
import '../screens/blurry_photos_screen.dart';
import 'package:flutter/foundation.dart';
import '../screens/photos_screen.dart';  // Add this import

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class BlurAnalysisResult {
  final bool isBlurry;
  final double blurScore; // Higher score means more blur
  
  BlurAnalysisResult({required this.isBlurry, required this.blurScore});
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

// Add these variable declarations
  bool _blurryPhotosAnalysisComplete = false;
  double _blurryPhotosAnalysisProgress = 0.0;
  List<AssetEntity> _blurryPhotoSamples = [];


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


// Laplacian variance method (primary method)
double _calculateLaplacianScore(img.Image image) {
  // Convert to grayscale
  final img.Image grayscale = img.grayscale(image);
  
  // Laplacian variance calculation
  List<double> edgeValues = [];
  
  // Sample every other pixel for performance
  for (int y = 1; y < grayscale.height - 1; y += 2) {
    for (int x = 1; x < grayscale.width - 1; x += 2) {
      // Full Laplacian kernel
      double center = img.getLuminance(grayscale.getPixel(x, y)).toDouble();
      double left = img.getLuminance(grayscale.getPixel(x-1, y)).toDouble();
      double right = img.getLuminance(grayscale.getPixel(x+1, y)).toDouble();
      double top = img.getLuminance(grayscale.getPixel(x, y-1)).toDouble();
      double bottom = img.getLuminance(grayscale.getPixel(x, y+1)).toDouble();
      
      // Simplified for performance but still effective
      double edgeStrength = (4 * center - left - right - top - bottom).abs();
      edgeValues.add(edgeStrength);
    }
  }
  
  if (edgeValues.isEmpty) return 100.0; // Not blurry if can't calculate
  
  // Calculate variance
  double sum = 0;
  for (double value in edgeValues) {
    sum += value;
  }
  double mean = sum / edgeValues.length;
  
  double varianceSum = 0;
  for (double value in edgeValues) {
    varianceSum += (value - mean) * (value - mean);
  }
  double variance = varianceSum / edgeValues.length;
  
  return variance; // Higher variance = less blur
}

// Gradient magnitude method (secondary method)
double _calculateGradientScore(img.Image image) {
  // Convert to grayscale
  final img.Image grayscale = img.grayscale(image);
  
  double totalGradient = 0.0;
  int gradientCount = 0;
  
  // Calculate horizontal and vertical gradients
  for (int y = 1; y < grayscale.height - 1; y += 3) {
    for (int x = 1; x < grayscale.width - 1; x += 3) {
      double horizontal = img.getLuminance(grayscale.getPixel(x+1, y)).toDouble() - 
                          img.getLuminance(grayscale.getPixel(x-1, y)).toDouble();
      double vertical = img.getLuminance(grayscale.getPixel(x, y+1)).toDouble() - 
                        img.getLuminance(grayscale.getPixel(x, y-1)).toDouble();
      
      // Gradient magnitude
      double magnitude = math.sqrt(horizontal * horizontal + vertical * vertical);

      totalGradient += magnitude;
      gradientCount++;
    }
  }
  
  if (gradientCount == 0) return 100.0;
  
  return totalGradient / gradientCount; // Higher gradient = less blur
}

// Frequency domain estimation (tertiary method)
double _estimateFrequencyScore(img.Image image) {
  // This is a simplified estimation of frequency content
  // Real frequency analysis would use FFT which is too heavy for mobile
  
  // Convert to grayscale
  final img.Image grayscale = img.grayscale(image);
  
  int highFreqCount = 0;
  int totalSamples = 0;
  
  // Check for rapid changes in small neighborhoods
  for (int y = 2; y < grayscale.height - 2; y += 4) {
    for (int x = 2; x < grayscale.width - 2; x += 4) {
      double center = img.getLuminance(grayscale.getPixel(x, y)).toDouble();
      
      // Check 8 surrounding pixels
      List<double> neighbors = [
        img.getLuminance(grayscale.getPixel(x-1, y-1)).toDouble(),
        img.getLuminance(grayscale.getPixel(x, y-1)).toDouble(),
        img.getLuminance(grayscale.getPixel(x+1, y-1)).toDouble(),
        img.getLuminance(grayscale.getPixel(x-1, y)).toDouble(),
        img.getLuminance(grayscale.getPixel(x+1, y)).toDouble(),
        img.getLuminance(grayscale.getPixel(x-1, y+1)).toDouble(),
        img.getLuminance(grayscale.getPixel(x, y+1)).toDouble(),
        img.getLuminance(grayscale.getPixel(x+1, y+1)).toDouble(),
      ];
      
      // Count significant differences (high frequency content)
      for (double neighbor in neighbors) {
        if ((center - neighbor).abs() > 15.0) { // Threshold for significant change
          highFreqCount++;
        }
        totalSamples++;
      }
    }
  }
  
  if (totalSamples == 0) return 100.0;
  
  // Return ratio of high frequency content
  return (highFreqCount / totalSamples) * 100.0; // Higher = less blur
}

@override
  void initState() {
    super.initState();
    
    // Initialize the progress controller
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    // Initialize with a default animation (will be updated in _updateProgressAnimation)
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(_progressController);
    
    _checkPermissions();
    _getStorageInfo();
    
    // Start all analyses after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
    });
  }
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
           // _buildTabSelector(),
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

Widget _buildAnalysisCards() {
  return Column(
    children: [
      // Manual Clean section with the layout from the image
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
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
              'Manual Clean',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Photos card
                Expanded(
                  child: _buildManualCleanCard(
                    icon: Icons.photo_camera,
                    iconColor: Colors.blue,
                    title: 'Photos',
                    subtitle: '1139 Photos to ...',
                    onTap: () {
                      // Navigate to Photos screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PhotosScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Videos card
                Expanded(
                  child: _buildManualCleanCard(
                    icon: Icons.video_library,
                    iconColor: Colors.green,
                    title: 'Videos',
                    subtitle: '106 Videos to c...',
                    onTap: () {
                      // Navigate to Videos screen
                      // You can add navigation to videos_screen.dart here when ready
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Contacts card
                Expanded(
                  child: _buildManualCleanCard(
                    icon: Icons.book,
                    iconColor: Colors.blue,
                    title: 'Contacts',
                    subtitle: 'Allow access',
                    showAccessIndicator: true,
                    onTap: () {
                      // Request contacts access
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Events card
                Expanded(
                  child: _buildManualCleanCard(
                    icon: Icons.calendar_today,
                    iconColor: Colors.purple,
                    title: 'Events',
                    subtitle: 'Allow access',
                    showAccessIndicator: true,
                    onTap: () {
                      // Request calendar access
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _buildManualCleanCard({
  required IconData icon,
  required Color iconColor,
  required String title,
  required String subtitle,
  bool showAccessIndicator = false,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                icon,
                color: iconColor,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showAccessIndicator)
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.blue,
                      width: 1.5,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
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