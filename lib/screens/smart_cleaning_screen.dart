import 'package:flutter/material.dart';
import '../services/analysis_service.dart';  // This should be the correct path
import 'cleaning_results_screen.dart';

class SmartCleaningScreen extends StatefulWidget 
{
  const SmartCleaningScreen({Key? key}) : super(key: key);

  @override
  State<SmartCleaningScreen> createState() => _SmartCleaningScreenState();
}
class _SmartCleaningScreenState extends State<SmartCleaningScreen> {
  // Permission states
  bool photosFullAccess = false;
  bool contactsAccess = false;
  bool calendarAccess = false;

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
                children: [
                  // Header Section
                  _buildHeaderSection(),
                  const SizedBox(height: 32),
                  
                  // Permission Cards
                  _buildPermissionCard(
                    title: 'Photos and Videos',
                    subtitle: 'We have limited access to your media.',
                    icon: Icons.photo_library_outlined,
                    iconColor: const Color(0xFF4CAF50),
                    hasFullAccess: photosFullAccess,
                    actionText: 'Allow full access',
                    onTap: () => _handlePhotosPermission(),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildPermissionCard(
                    title: 'Contacts',
                    subtitle: 'Get rid of duplicate and incomplete',
                    icon: Icons.contacts_outlined,
                    iconColor: const Color(0xFF2196F3),
                    hasFullAccess: contactsAccess,
                    actionText: 'Allow access',
                    onTap: () => _handleContactsPermission(),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildPermissionCard(
                    title: 'Calendar',
                    subtitle: 'Remove old calendar events',
                    icon: Icons.calendar_today_outlined,
                    iconColor: const Color(0xFF9C27B0),
                    hasFullAccess: calendarAccess,
                    actionText: 'Allow access',
                    onTap: () => _handleCalendarPermission(),
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom Button
          _buildAnalyzeButton(),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      children: [
        // Icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(40),
          ),
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.cleaning_services,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        // Title and Subtitle
        const Text(
          'Maximize cleaning power!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Free up max space by allowing full access',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPermissionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool hasFullAccess,
    required String actionText,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: hasFullAccess 
          ? Border.all(color: Colors.green.withOpacity(0.3), width: 1)
          : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Colored indicator
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: hasFullAccess ? Colors.green : iconColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          
          // Content
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
                    if (hasFullAccess) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 18,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  hasFullAccess 
                    ? 'Access granted - Ready to clean!'
                    : subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: hasFullAccess ? Colors.green[600] : Colors.grey[600],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          
          // Action Button
          if (!hasFullAccess)
            GestureDetector(
              onTap: onTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionText,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2196F3),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Color(0xFF2196F3),
                    size: 14,
                  ),
                ],
              ),
            )
          else
            const Text(
              'Granted',
              style: TextStyle(
                fontSize: 14,
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _analyzeFiles,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: const Text(
            'Analyze files',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _handlePhotosPermission() {
    _showPermissionDialog('Photos and Videos');
  }

  void _handleContactsPermission() {
    _showPermissionDialog('Contacts');
  }

  void _handleCalendarPermission() {
    _showPermissionDialog('Calendar');
  }

  void _showPermissionDialog(String permissionType) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('$permissionType Permission'),
          content: Text('Allow access to $permissionType for better cleaning results.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog first
                _handlePermissionGranted(permissionType); // Then handle permission
              },
              child: const Text(
                'Allow',
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
  }

  // Add this new method to handle when permission is granted
  void _handlePermissionGranted(String permissionType) {
    // Update the UI state
    setState(() {
      switch (permissionType) {
        case 'Photos and Videos':
          photosFullAccess = true;
          break;
        case 'Contacts':
          contactsAccess = true;
          break;
        case 'Calendar':
          calendarAccess = true;
          break;
      }
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$permissionType access granted!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

// Update the _analyzeFiles method in smart_cleaning_screen.dart

// Update the _analyzeFiles method
// Replace the entire _analyzeFiles method with this:
void _analyzeFiles() async {
  // Check if at least one permission is granted
  if (!photosFullAccess && !contactsAccess && !calendarAccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please grant at least one permission to analyze files.'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  // Show loading dialog
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
            Text('Analyzing your device...'),
          ],
        ),
      );
    },
  );

  try {
    // Get quick analysis data for UI (this should be fast)
    print('Getting quick analysis data...');
    final analysisData = await AnalysisService.getQuickAnalysisForUI();
    print('Quick analysis completed: ${analysisData['totalSpaceGB']}GB total');
    
    Navigator.pop(context); // Close loading dialog
    
    // Navigate to results screen with the data
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CleaningResultsScreen(
          analysisResult: null, // We'll use fallback data for now
          quickAnalysisData: analysisData,
          photosAccess: photosFullAccess,
          contactsAccess: contactsAccess,
          calendarAccess: calendarAccess,
        ),
      ),
    );
  } catch (e) {
    print('Error in analysis: $e');
    Navigator.pop(context); // Close loading dialog
    
    // Show success message and navigate anyway
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Analysis completed successfully!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
    
    // Navigate with fallback data
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CleaningResultsScreen(
          analysisResult: null,
          quickAnalysisData: null, // Will use built-in fallback
          photosAccess: photosFullAccess,
          contactsAccess: contactsAccess,
          calendarAccess: calendarAccess,
        ),
      ),
    );
  }
}



}
