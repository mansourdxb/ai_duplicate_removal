import 'package:flutter/material.dart';
import 'dart:io';
import '../models/duplicate_item.dart';

class DuplicateGroupWidget extends StatefulWidget {
  final List<DuplicateItem> group;
  final Set<DuplicateItem> selectedItems;
  final Function(DuplicateItem, bool) onSelectionChanged;

  const DuplicateGroupWidget({
    Key? key,
    required this.group,
    required this.selectedItems,
    required this.onSelectionChanged,
  }) : super(key: key);

  @override
  State<DuplicateGroupWidget> createState() => _DuplicateGroupWidgetState();
}

class _DuplicateGroupWidgetState extends State<DuplicateGroupWidget> {
  String sortOption = 'newest'; // Default sorting option

  FileType _parseFileType(String? type) {
    switch (type) {
      case 'image':
        return FileType.image;
      case 'document':
        return FileType.document;
      case 'video':
        return FileType.video;
      case 'audio':
        return FileType.audio;
      default:
        return FileType.document; // fallback to document
    }
  }

  List<DuplicateItem> _getSortedGroup() {
    final sorted = List<DuplicateItem>.from(widget.group);
    
    switch (sortOption) {
      case 'newest':
        sorted.sort((a, b) {
          final aDate = a.lastModified ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.lastModified ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate); // Newest first
        });
        break;
      case 'oldest':
        sorted.sort((a, b) {
          final aDate = a.lastModified ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.lastModified ?? DateTime.fromMillisecondsSinceEpoch(0);
          return aDate.compareTo(bDate); // Oldest first
        });
        break;
      case 'largest':
        sorted.sort((a, b) {
          final aSize = a.size ?? 0;
          final bSize = b.size ?? 0;
          return bSize.compareTo(aSize); // Largest first
        });
        break;
      case 'smallest':
        sorted.sort((a, b) {
          final aSize = a.size ?? 0;
          final bSize = b.size ?? 0;
          return aSize.compareTo(bSize); // Smallest first
        });
        break;
    }
    
    return sorted;
  }

  bool _isRecommendedToKeep(DuplicateItem item, int index) {
    // The first item in the sorted list is recommended to keep
    return index == 0;
  }

  @override
  Widget build(BuildContext context) {
    final sortedGroup = _getSortedGroup();

    return Card(
      margin: const EdgeInsets.all(8),
      child: ExpansionTile(
        title: Row(
          children: [
            _getFileTypeIcon(_parseFileType(widget.group.first.fileType)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.group.length} duplicate files',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${widget.group.first.sizeFormatted} each • ${_getTotalWastedSpace()}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            if (widget.group.first.similarity < 1.0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${widget.group.first.similarityPercentage} match',
                  style: TextStyle(fontSize: 10, color: Colors.orange[800]),
                ),
              ),
          ],
        ),
        children: [
          // Sort Options
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'Keep:',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      _buildSortChip('newest', 'Newest'),
                      _buildSortChip('oldest', 'Oldest'),
                      _buildSortChip('largest', 'Largest'),
                      _buildSortChip('smallest', 'Smallest'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // File List
          ...sortedGroup.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildFileItem(item, context, index);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSortChip(String value, String label) {
    final isSelected = sortOption == value;
    return GestureDetector(
      onTap: () => setState(() => sortOption = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[100] : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.blue[300]! : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.blue[700] : Colors.grey[700],
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildFileItem(DuplicateItem item, BuildContext context, int index) {
    final isSelected = widget.selectedItems.contains(item);
    final isRecommendedToKeep = _isRecommendedToKeep(item, index);

    return Container(
      color: isSelected 
          ? Colors.red[50] 
          : (isRecommendedToKeep ? Colors.green[50] : null),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isRecommendedToKeep)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.star,
                  color: Colors.green[700],
                  size: 16,
                ),
              )
            else
              Checkbox(
                value: isSelected,
                onChanged: (value) => widget.onSelectionChanged(item, value ?? false),
                activeColor: Colors.red[600],
              ),
            if (item.fileType == FileType.image)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.file(
                    File(item.paths?.first ?? ''),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.broken_image, size: 20),
                  ),
                ),
              )
            else
              _getFileTypeIcon(_parseFileType(item.fileType)),
          ],
        ),
        title: Text(
          item.name ?? '',
          style: const TextStyle(fontSize: 14),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.path ?? '',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  'Modified: ${item.lastModified != null ? _formatDate(item.lastModified!) : 'Unknown'}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                if (isRecommendedToKeep) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'KEEP',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.green[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              item.sizeFormatted,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            if (item.similarity < 1.0)
              Text(
                item.similarityPercentage,
                style: TextStyle(fontSize: 11, color: Colors.orange[600]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _getFileTypeIcon(FileType fileType) {
    IconData iconData;
    Color color;

    switch (fileType) {
      case FileType.image:
        iconData = Icons.image;
        color = Colors.blue;
        break;
      case FileType.document:
        iconData = Icons.description;
        color = Colors.red;
        break;
      case FileType.video:
        iconData = Icons.videocam;
        color = Colors.purple;
        break;
      case FileType.audio:
        iconData = Icons.audiotrack;
        color = Colors.orange;
        break;
      default:
        iconData = Icons.insert_drive_file;
        color = Colors.grey;
    }

    return Icon(iconData, color: color, size: 24);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return '${difference}d ago';
    if (difference < 30) return '${(difference / 7).floor()}w ago';
    if (difference < 365) return '${(difference / 30).floor()}mo ago';
    return '${(difference / 365).floor()}y ago';
  }

  String _getTotalWastedSpace() {
    if (widget.group.isEmpty) return '0 B wasted';
    
    final wastedSize = (widget.group.first.size ?? 0) * (widget.group.length - 1);
    if (wastedSize < 1024) return '$wastedSize B wasted';
    if (wastedSize < 1024 * 1024) return '${(wastedSize / 1024).toStringAsFixed(1)} KB wasted';
    if (wastedSize < 1024 * 1024 * 1024) return '${(wastedSize / (1024 * 1024)).toStringAsFixed(1)} MB wasted';
    return '${(wastedSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB wasted';
  }
}
