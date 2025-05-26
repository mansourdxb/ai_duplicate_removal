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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Duplicate Removal AI'),
        centerTitle: true,
      ),
      body: BlocListener<DuplicateBloc, DuplicateState>(
        listener: (context, state) {
          if (state is DuplicateError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is DuplicateDetected) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ResultsScreen(duplicates: state.duplicates),
              ),
            );
          } else if (state is DuplicateContactsDetected) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ContactResultsScreen(duplicates: state.duplicates),
              ),
            );
          } else if (state is DuplicateMixedDetected) {
            // Show mixed results screen or let user choose
            _showMixedResultsDialog(context, state);
          }
        },
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.auto_fix_high,
                        size: 64,
                        color: Colors.blue[600],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'AI-Powered Duplicate Detection',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Find and remove duplicate files, images, and documents using advanced AI algorithms',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),
              _buildScanOption(
                context,
                icon: Icons.photo_library,
                title: 'Scan Images',
                subtitle: 'Find duplicate photos and images',
                onTap: () => _startScan(context, ScanType.images),
              ),
              SizedBox(height: 12),
              _buildScanOption(
                context,
                icon: Icons.contacts,
                title: 'Scan Contacts',
                subtitle: 'Find duplicate contacts and phone numbers',
                onTap: () => _startScan(context, ScanType.contacts),
              ),
              SizedBox(height: 12),
              _buildScanOption(
                context,
                icon: Icons.folder,
                title: 'Scan Files',
                subtitle: 'Find duplicate documents and files',
                onTap: () => _startScan(context, ScanType.files),
              ),
              SizedBox(height: 12),
              _buildScanOption(
                context,
                icon: Icons.select_all,
                title: 'Full Scan',
                subtitle: 'Comprehensive scan of all file types',
                onTap: () => _startScan(context, ScanType.all),
              ),
              Spacer(),
              BlocBuilder<DuplicateBloc, DuplicateState>(
                builder: (context, state) {
                  if (state is DuplicateScanning) {
                    return Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Scanning for duplicates...'),
                            Text(
                              state.progress,
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue[50],
          child: Icon(icon, color: Colors.blue[600]),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }

  void _startScan(BuildContext context, ScanType scanType) {
    context.read<DuplicateBloc>().add(StartScan(scanType));
  }

  void _showMixedResultsDialog(BuildContext context, DuplicateMixedDetected state) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Duplicates Found'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.fileDuplicates.isNotEmpty)
              Text('• ${state.fileDuplicates.length} file duplicate groups'),
            if (state.contactDuplicates.isNotEmpty)
              Text('• ${state.contactDuplicates.length} contact duplicate groups'),
          ],
        ),
        actions: [
          if (state.fileDuplicates.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ResultsScreen(duplicates: state.fileDuplicates),
                  ),
                );
              },
              child: Text('View Files'),
            ),
          if (state.contactDuplicates.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ContactResultsScreen(duplicates: state.contactDuplicates),
                  ),
                );
              },
              child: Text('View Contacts'),
            ),
        ],
      ),
    );
  }
}