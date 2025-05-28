import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/duplicate_bloc.dart';
import '../bloc/duplicate_event.dart';
import '../bloc/duplicate_state.dart';
import '../models/duplicate_item.dart';
import '../models/duplicate_contact.dart';
import 'results_screen.dart';
import 'contact_results_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Duplicate Removal AI',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        shadowColor: Colors.grey.withOpacity(0.1),
        surfaceTintColor: Colors.transparent,
      ),
      body: BlocListener<DuplicateBloc, DuplicateState>(
        listener: (context, state) {
          if (state is DuplicateError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(child: Text(state.message)),
                  ],
                ),
                backgroundColor: Colors.red[600],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.all(16),
              ),
            );
          } else if (state is DuplicateDetected) {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    ResultsScreen(duplicates: state.duplicates),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: animation.drive(
                      Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                          .chain(CurveTween(curve: Curves.easeInOut)),
                    ),
                    child: child,
                  );
                },
              ),
            );
          } else if (state is DuplicateContactsDetected) {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    ContactResultsScreen(duplicates: state.duplicates),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: animation.drive(
                      Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                          .chain(CurveTween(curve: Curves.easeInOut)),
                    ),
                    child: child,
                  );
                },
              ),
            );
          } else if (state is DuplicateMixedDetected) {
            _showMixedResultsDialog(context, state);
          }
        },
        child: Column(
          children: [
            // Hero Section - Compact
            Container(
              margin: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue[600]!,
                    Colors.blue[700]!,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.auto_fix_high_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'AI-Powered Duplicate Detection',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Find and remove duplicate files, images, and documents using advanced AI algorithms',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            
            // Scan Options Section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose Scan Type',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildScanOption(
                            context,
                            icon: Icons.photo_library_rounded,
                            title: 'Scan Images',
                            subtitle: 'Find duplicate photos and images',
                            color: Colors.purple,
                            onTap: () => _startScan(context, ScanType.images),
                          ),
                          const SizedBox(height: 12),
                          _buildScanOption(
                            context,
                            icon: Icons.contacts_rounded,
                            title: 'Scan Contacts',
                            subtitle: 'Find duplicate contacts and phone numbers',
                            color: Colors.green,
                            onTap: () => _startScan(context, ScanType.contacts),
                          ),
                          const SizedBox(height: 12),
                          _buildScanOption(
                            context,
                            icon: Icons.folder_rounded,
                            title: 'Scan Files',
                            subtitle: 'Find duplicate documents and files',
                            color: Colors.orange,
                            onTap: () => _startScan(context, ScanType.files),
                          ),
                          const SizedBox(height: 12),
                          _buildScanOption(
                            context,
                            icon: Icons.scanner_rounded,
                            title: 'Full Scan',
                            subtitle: 'Comprehensive scan of all file types',
                            color: Colors.red,
                            onTap: () => _startScan(context, ScanType.all),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Progress Section - Fixed at bottom
            BlocBuilder<DuplicateBloc, DuplicateState>(
              builder: (context, state) {
                if (state is DuplicateScanning) {
                  return Container(
                    margin: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Scanning for duplicates...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  state.progress,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startScan(BuildContext context, ScanType scanType) {
    context.read<DuplicateBloc>().add(StartScan(scanType));
  }

  void _showMixedResultsDialog(BuildContext context, DuplicateMixedDetected state) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.check_circle_rounded,
                color: Colors.green[600],
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Duplicates Found',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.fileDuplicates.isNotEmpty)
              _buildResultItem(
                Icons.folder_rounded,
                '${state.fileDuplicates.length} file duplicate groups',
                Colors.orange,
              ),
            if (state.fileDuplicates.isNotEmpty && state.contactDuplicates.isNotEmpty)
              const SizedBox(height: 12),
            if (state.contactDuplicates.isNotEmpty)
              _buildResultItem(
                Icons.contacts_rounded,
                '${state.contactDuplicates.length} contact duplicate groups',
                Colors.green,
              ),
          ],
        ),
        actions: [
          if (state.fileDuplicates.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ResultsScreen(duplicates: state.fileDuplicates),
                  ),
                );
              },
              icon: const Icon(Icons.folder_rounded),
              label: const Text('View Files'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          if (state.contactDuplicates.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ContactResultsScreen(duplicates: state.contactDuplicates),
                  ),
                );
              },
              icon: const Icon(Icons.contacts_rounded),
              label: const Text('View Contacts'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultItem(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }
}