enum ScanType {
  images,
  videos,
  files,
  screenshots,
}

extension ScanTypeExtension on ScanType {
  String get displayName {
    switch (this) {
      case ScanType.images:
        return 'Images';
      case ScanType.videos:
        return 'Videos';
      case ScanType.files:
        return 'Files';
      case ScanType.screenshots:
        return 'Screenshots';
    }
  }

  String get description {
    switch (this) {
      case ScanType.images:
        return 'Find similar and duplicate images';
      case ScanType.videos:
        return 'Find duplicate video files';
      case ScanType.files:
        return 'Find duplicate documents and files';
      case ScanType.screenshots:
        return 'Find and organize screenshots';
    }
  }
}
