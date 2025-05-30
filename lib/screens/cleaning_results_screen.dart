import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import '../services/analysis_service.dart'; // Update this path - remove 'screens/' if analysis_service.dart is in lib folder
// OR if analysis_service.dart is in lib/services/ folder:
// import '../services/analysis_service.dart';

class CleaningResultsScreen extends StatefulWidget {
  final ComprehensiveAnalysisResult? analysisResult;
  final Map<String, dynamic>? quickAnalysisData; // Add this line
  final bool photosAccess;
  final bool contactsAccess;
  final bool calendarAccess;

  const CleaningResultsScreen({
    Key? key,
    required this.analysisResult,
    this.quickAnalysisData, // Add this line
    required this.photosAccess,
    required this.contactsAccess,
    required this.calendarAccess,
  }) : super(key: key);

  @override
  State<CleaningResultsScreen> createState() => _CleaningResultsScreenState();
}

class _CleaningResultsScreenState extends State<CleaningResultsScreen> {
  bool photosExpanded = false;
  bool videosExpanded = false;
  bool contactsExpanded = false;
  bool eventsExpanded = false;

  // Add getter methods to handle both old and new data sources
  double get _totalSpaceFoundGB {
    if (widget.analysisResult != null) {
      return widget.analysisResult!.totalSpaceFound / (1024 * 1024 * 1024);
    }
    return 3.6; // Default fallback
  }

  double get _cleanupPercentage {
    if (widget.analysisResult != null) {
      return widget.analysisResult!.cleanupPercentage;
    }
    return 38.0; // Default fallback
  }

  // Photo data getters
  int get _photoCount {
    return widget.analysisResult?.photos.count ?? 1529;
  }

  String get _photoSize {
    return widget.analysisResult?.photos.formattedSize ?? '2.5GB';
  }

  int get _similarPhotos {
    return widget.analysisResult?.similar.count ?? 1096;
  }

  int get _duplicatePhotos {
    return widget.analysisResult?.duplicates.count ?? 0;
  }

  int get _screenshots {
    return widget.analysisResult?.screenshots.count ?? 140;
  }

  int get _blurryPhotos {
    return widget.analysisResult?.blurry.count ?? 293;
  }

  // Video data getters
  int get _videoCount {
    return widget.analysisResult?.videos.count ?? 11;
  }

  String get _videoSize {
    return widget.analysisResult?.videos.formattedSize ?? '868.2MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4285F4), Color(0xFF34A853)],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Smart Cleaning',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card - Updated with dynamic data
                  _buildHeaderCard(),
                  const SizedBox(height: 24),
                  
                  // Storage Optimization Title
                  const Text(
                    'Optimize your storage',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Storage Categories - Updated with dynamic data
                  if (widget.photosAccess) ...[
                    _buildStorageCategory(
                      title: '$_photoCount Photos',
                      subtitle: _photoSize,
                      description: 'Photos are moved to your recycle bin',
                      color: const Color(0xFF4CAF50),
                      isExpanded: photosExpanded,
                      onTap: () => setState(() => photosExpanded = !photosExpanded),
                      items: [
                        _buildStorageItem('Similar', _similarPhotos, true),
                        _buildStorageItem('Duplicate', _duplicatePhotos, true),
                        _buildStorageItem('Screenshots', _screenshots, true),
                        _buildStorageItem('Blurry', _blurryPhotos, true),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    _buildStorageCategory(
                      title: '$_videoCount Videos',
                      subtitle: _videoSize,
                      description: 'Videos are moved to your recycle bin',
                      color: const Color(0xFF2196F3),
                      isExpanded: videosExpanded,
                      onTap: () => setState(() => videosExpanded = !videosExpanded),
                      items: [],
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  if (widget.contactsAccess) ...[
                    _buildStorageCategory(
                      title: '0 Contacts',
                      subtitle: '',
                      description: 'Backup created with each cleaning',
                      color: const Color(0xFF9C27B0),
                      isExpanded: contactsExpanded,
                      onTap: () => setState(() => contactsExpanded = !contactsExpanded),
                      items: [],
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  if (widget.calendarAccess) ...[
                    _buildStorageCategory(
                      title: 'Past Events',
                      subtitle: '',
                      description: 'Past events are permanently deleted',
                      color: const Color(0xFFFF9800),
                      isExpanded: eventsExpanded,
                      onTap: () => setState(() => eventsExpanded = !eventsExpanded),
                      items: [],
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
          
          // Bottom Button
          _buildStartCleaningButton(),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Give your phone a boost',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'A faster and smoother\nphone after clean-up',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      text: TextSpan(
                        text: 'Free up to ',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        children: [
                          TextSpan(
                            text: '${_totalSpaceFoundGB.toStringAsFixed(1)}GB',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2196F3),
                            ),
                          ),
                          const TextSpan(
                            text: ' for a\nlag-free phone!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Circular Progress - Updated with dynamic percentage
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: _cleanupPercentage / 100,
                        strokeWidth: 6,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF2196F3),
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        '${_cleanupPercentage.round()}%',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2196F3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Category Legend
          Row(
            children: [
              _buildLegendItem('Photos', const Color(0xFF4CAF50)),
              _buildLegendItem('Videos', const Color(0xFF2196F3)),
              _buildLegendItem('Contacts', const Color(0xFF9C27B0)),
              _buildLegendItem('Events', const Color(0xFFFF9800)),
              _buildLegendItem('Other', Colors.grey[300]!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageCategory({
    required String title,
    required String subtitle,
    required String description,
    required Color color,
    required bool isExpanded,
    required VoidCallback onTap,
    required List<Widget> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            if (subtitle.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                subtitle,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          
          if (isExpanded && items.isNotEmpty) ...[
            const Divider(height: 1),
            ...items,
          ],
        ],
      ),
    );
  }

  Widget _buildStorageItem(String label, int count, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const SizedBox(width: 20),
          Icon(
            isSelected ? Icons.check_box : Icons.check_box_outline_blank,
            color: isSelected ? const Color(0xFF2196F3) : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
          Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF2196F3),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.arrow_forward_ios,
            color: Colors.grey,
            size: 12,
          ),
        ],
      ),
    );
  }

  Widget _buildStartCleaningButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _startCleaning,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Start Cleaning',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.auto_awesome, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Allow access ⭕',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  void _startCleaning() {
    // Show cleaning progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Cleaning in progress...'),
            ],
          ),
        );
      },
    );

    // Simulate cleaning process
    Future.delayed(const Duration(seconds: 4), () {
      Navigator.pop(context); // Close progress dialog
      
      // Show completion dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Cleaning Complete! 🎉'),
            content: Text('Successfully freed up ${_totalSpaceFoundGB.toStringAsFixed(1)}GB of storage space!'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to main screen
                  Navigator.pop(context); // Go back to main screen
                },
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: Color(0xFF2196F3),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      );
    });
  }
}
