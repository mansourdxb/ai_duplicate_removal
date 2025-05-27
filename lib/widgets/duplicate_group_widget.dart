import 'package:flutter/material.dart';
import 'dart:io';
import '../models/duplicate_item.dart';

class DuplicateGroupWidget extends StatelessWidget {
  final List<DuplicateItem> group;
  final Set<DuplicateItem> selectedItems;
  final Function(DuplicateItem, bool) onSelectionChanged;

  const DuplicateGroupWidget({
    Key? key,
    required this.group,
    required this.selectedItems,
    required this.onSelectionChanged,
  }) : super(key: key);


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

  @override
  Widget build(BuildContext context) {
    // Sort group by modification date (newest first)
    final sortedGroup = List<DuplicateItem>.from(group)
      ..sort((a, b) => b.lastModified!.compareTo(a.lastModified!));


    return Card(
  margin: EdgeInsets.all(8),
  child: ExpansionTile(
    title: Row(
      children: [
        _getFileTypeIcon(_parseFileType(group.first.fileType)),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${group.length} duplicate files',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${group.first.sizeFormatted} each • ${_getTotalWastedSpace()}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
        if (group.first.similarity < 1.0)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${group.first.similarityPercentage} match',
              style: TextStyle(fontSize: 10, color: Colors.orange[800]),
            ),
          ),
      ],
    ),
    children: sortedGroup.map((item) => _buildFileItem(item, context)).toList(),
  ),
);

  }

  Widget _buildFileItem(DuplicateItem item, BuildContext context) {
    final isSelected = selectedItems.contains(item);
    final isNewest = group.first.lastModified == item.lastModified;

    return Container(
      color: isSelected ? Colors.blue[50] : null,
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (value) => onSelectionChanged(item, value ?? false),
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
                    File(item.path!),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => 
                        Icon(Icons.broken_image, size: 20),
                  ),
                ),
              )
            else
              _getFileTypeIcon(_parseFileType(item.fileType)),
          ],
        ),
        title: Text(
          item.name ?? '',
          style: TextStyle(fontSize: 14),
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
            SizedBox(height: 2),
            Row(
              children: [
                Text(
                  'Modified: ${item.lastModified != null ? _formatDate(item.lastModified!) : 'Unknown'}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                if (isNewest) ...[
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'NEWEST',
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
              style: TextStyle(fontWeight: FontWeight.w500),
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
    if (group.isEmpty) return '0 B wasted';
    
    final wastedSize = (group.first.size ?? 0) * (group.length - 1);
    if (wastedSize < 1024) return '$wastedSize B wasted';
    if (wastedSize < 1024 * 1024) return '${(wastedSize / 1024).toStringAsFixed(1)} KB wasted';
    if (wastedSize < 1024 * 1024 * 1024) return '${(wastedSize / (1024 * 1024)).toStringAsFixed(1)} MB wasted';
    return '${(wastedSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB wasted';
  }
}