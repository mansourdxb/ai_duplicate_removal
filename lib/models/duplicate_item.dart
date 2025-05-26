import 'package:equatable/equatable.dart';
import 'dart:io';

class DuplicateItem extends Equatable {
  final String path;
  final String name;
  final int size;
  final DateTime lastModified;
  final String hash;
  final FileType fileType;
  final double similarity;

  const DuplicateItem({
    required this.path,
    required this.name,
    required this.size,
    required this.lastModified,
    required this.hash,
    required this.fileType,
    this.similarity = 1.0,
  });

  factory DuplicateItem.fromFile(File file, String hash, {double similarity = 1.0}) {
    final stat = file.statSync();
    final extension = file.path.split('.').last.toLowerCase();
    
    return DuplicateItem(
      path: file.path,
      name: file.path.split('/').last,
      size: stat.size,
      lastModified: stat.modified,
      hash: hash,
      fileType: _getFileType(extension),
      similarity: similarity,
    );
  }

  static FileType _getFileType(String extension) {
    final imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
    final documentExtensions = ['pdf', 'doc', 'docx', 'txt', 'rtf'];
    final videoExtensions = ['mp4', 'avi', 'mov', 'mkv', 'wmv'];
    final audioExtensions = ['mp3', 'wav', 'flac', 'aac', 'm4a'];

    if (imageExtensions.contains(extension)) return FileType.image;
    if (documentExtensions.contains(extension)) return FileType.document;
    if (videoExtensions.contains(extension)) return FileType.video;
    if (audioExtensions.contains(extension)) return FileType.audio;
    
    return FileType.other;
  }

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get similarityPercentage => '${(similarity * 100).toStringAsFixed(1)}%';

  @override
  List<Object> get props => [path, name, size, lastModified, hash, fileType, similarity];
}

enum FileType {
  image,
  document,
  video,
  audio,
  other,
}