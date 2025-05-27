import 'package:flutter/material.dart';
import '../models/duplicate_contact.dart' as model;
import '../services/contact_service.dart';
import '../widgets/contact_group_widget.dart';

class ContactResultsScreen extends StatefulWidget {
  final List<List<model.DuplicateContact>> duplicates;

  const ContactResultsScreen({Key? key, required this.duplicates}) : super(key: key);

  @override
  State<ContactResultsScreen> createState() => _ContactResultsScreenState();
}

class _ContactResultsScreenState extends State<ContactResultsScreen> {
  final Set<model.DuplicateContact> selectedContacts = {};
  final ContactService contactService = ContactService();
  bool isProcessing = false;
  bool selectAll = false;

  @override
  Widget build(BuildContext context) {
    final totalDuplicates = widget.duplicates.fold<int>(
      0, (sum, group) => sum + group.length - 1
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Duplicate Contacts'),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
          ),
          IconButton(
            icon: Icon(Icons.select_all),
            onPressed: _toggleSelectAll,
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Card
          Container(
            width: double.infinity,
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Duplicate Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                SizedBox(height: 8),
                Text('Found ${widget.duplicates.length} duplicate groups'),
                Text('Total duplicates: $totalDuplicates'),
                Text('Selected for removal: ${selectedContacts.length}'),
              ],
            ),
          ),
          
          // Action Buttons
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: selectedContacts.isEmpty ? null : _removeDuplicates,
                    icon: Icon(Icons.delete),
                    label: Text('Remove Selected (${selectedContacts.length})'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _autoSelectDuplicates,
                  icon: Icon(Icons.auto_fix_high),
                  label: Text('Auto Select'),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 16),
          
          // Duplicate Groups List
          Expanded(
            child: widget.duplicates.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 64,
                          color: Colors.green,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No duplicates found!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text('Your contacts are clean.'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.duplicates.length,
                    itemBuilder: (context, index) {
                      final group = widget.duplicates[index];
                      return ContactGroupWidget(
                        group: group,
                        selectedContacts: selectedContacts,
                        onContactToggled: _toggleContactSelection,
                        groupIndex: index + 1,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _toggleContactSelection(model.DuplicateContact contact) {
    setState(() {
      if (selectedContacts.contains(contact)) {
        selectedContacts.remove(contact);
      } else {
        selectedContacts.add(contact);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (selectAll) {
        selectedContacts.clear();
      } else {
        // Select all except the first contact in each group (keep the original)
        for (var group in widget.duplicates) {
          for (int i = 1; i < group.length; i++) {
            selectedContacts.add(group[i]);
          }
        }
      }
      selectAll = !selectAll;
    });
  }

  void _autoSelectDuplicates() {
    setState(() {
      selectedContacts.clear();
      // Auto-select duplicates based on quality score
      for (var group in widget.duplicates) {
        // Sort by quality score (assuming higher is better)
        var sortedGroup = List<model.DuplicateContact>.from(group);
        sortedGroup.sort((a, b) => b.qualityScore.compareTo(a.qualityScore));
        
        // Keep the best one, select others for removal
        for (int i = 1; i < sortedGroup.length; i++) {
          selectedContacts.add(sortedGroup[i]);
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Auto-selected ${selectedContacts.length} duplicates for removal'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _removeDuplicates() async {
    if (selectedContacts.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Removal'),
        content: Text(
          'Are you sure you want to remove ${selectedContacts.length} duplicate contacts? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      isProcessing = true;
    });

    try {
      await ContactService.removeContacts(selectedContacts.toList().cast<model.DuplicateContact>());
      
      setState(() {
        // Remove deleted contacts from groups
        for (var group in widget.duplicates) {
          group.removeWhere((contact) => selectedContacts.contains(contact));
        }
        // Remove empty groups
        widget.duplicates.removeWhere((group) => group.length <= 1);
        selectedContacts.clear();
        isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully removed duplicate contacts'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        isProcessing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing contacts: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('How to Remove Duplicates'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHelpItem(
                '1. Review Groups',
                'Each card shows a group of duplicate contacts. Review them carefully.',
              ),
              _buildHelpItem(
                '2. Select Duplicates',
                'Tap contacts to select them for removal. Keep the most complete contact.',
              ),
              _buildHelpItem(
                '3. Auto Select',
                'Use "Auto Select" to automatically choose duplicates based on data quality.',
              ),
              _buildHelpItem(
                '4. Remove Selected',
                'Tap "Remove Selected" to permanently delete chosen duplicates.',
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Warning: Removed contacts cannot be recovered. Please review carefully.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String title, String description) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}