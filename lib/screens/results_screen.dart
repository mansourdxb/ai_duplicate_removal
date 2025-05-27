import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/duplicate_bloc.dart';
import '../bloc/duplicate_event.dart';
import '../models/duplicate_item.dart';
import '../widgets/duplicate_group_widget.dart';

class ResultsScreen extends StatefulWidget {
  final List<List<DuplicateItem>> duplicates;

  const ResultsScreen({Key? key, required this.duplicates}) : super(key: key);

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final Set<DuplicateItem> selectedItems = {};
  bool selectAllMode = false;

  @override
  Widget build(BuildContext context) {
    final totalDuplicates = widget.duplicates.fold<int>(
      0, (sum, group) => sum + group.length - 1
    );
    
    final totalSize = _calculateTotalSize();

    return Scaffold(
      appBar: AppBar(
        title: Text('Duplicate Results'),
        actions: [
          IconButton(
            icon: Icon(selectAllMode ? Icons.deselect : Icons.select_all),
            onPressed: _toggleSelectAll,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Found ${widget.duplicates.length} duplicate groups',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$totalDuplicates duplicate files • ${_formatSize(totalSize)} potential savings',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                if (selectedItems.isNotEmpty)
                  Chip(
                    label: Text('${selectedItems.length} selected'),
                    backgroundColor: Colors.blue[100],
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.duplicates.length,
              itemBuilder: (context, index) {
                final group = widget.duplicates[index];
                return DuplicateGroupWidget(
                  group: group,
                  selectedItems: selectedItems,
                  onSelectionChanged: (item, isSelected) {
                    setState(() {
                      if (isSelected) {
                        selectedItems.add(item);
                      } else {
                        selectedItems.remove(item);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: selectedItems.isNotEmpty
          ? Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${selectedItems.length} files selected',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_formatSize(_calculateSelectedSize())} will be freed',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _removeSelected,
                    icon: Icon(Icons.delete),
                    label: Text('Remove'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  void _toggleSelectAll() {
    setState(() {
      if (selectAllMode) {
        selectedItems.clear();
        selectAllMode = false;
      } else {
        // Select oldest files from each group (keep newest)
        for (final group in widget.duplicates) {
          final sortedGroup = List<DuplicateItem>.from(group)
            ..sort((a, b) {
              final aDate = a.lastModified ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bDate = b.lastModified ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bDate.compareTo(aDate);
            });
          
          // Add all but the newest file
          for (int i = 1; i < sortedGroup.length; i++) {
            selectedItems.add(sortedGroup[i]);
          }
        }
        selectAllMode = true;
      }
    });
  }

  void _removeSelected() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Deletion'),
        content: Text(
          'Are you sure you want to delete ${selectedItems.length} files? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<DuplicateBloc>().add(
                RemoveDuplicates(selectedItems.toList()),
              );
              Navigator.pop(context);
            },
            child: Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  int _calculateTotalSize() {
    int total = 0;
    for (final group in widget.duplicates) {
      // Calculate size of duplicates (excluding one original)
      if (group.isNotEmpty) {
        final sizePerFile = group.first.size;
        total += ((sizePerFile ?? 0) * (group.length - 1)).toInt();


      }
    }
    return total;
  }

  int _calculateSelectedSize() {
    return selectedItems.fold(0, (sum, item) => sum + (item.size ?? 0));
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}