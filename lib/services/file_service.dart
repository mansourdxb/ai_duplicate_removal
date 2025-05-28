import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class FileService {
  static const List<String> imageExtensions = [
    'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'tiff', 'ico'
  ];
  
  static const List<String> documentExtensions = [
    'pdf', 'doc', 'docx', 'txt', 'rtf', 'odt', 'xls', 'xlsx', 'ppt', 'pptx'
  ];

  Future<bool> requestPermissions() async {
    final status = await Permission.storage.request();
    if (status != PermissionStatus.granted) {
      final manageStatus = await Permission.manageExternalStorage.request();
      return manageStatus == PermissionStatus.granted;
    }
    return true;
  }

  Future<List<String>> getImageFiles() async {
    if (!await requestPermissions()) {
      throw Exception('Storage permission denied');
    }
    
    return await _getFilesByExtensions(imageExtensions);
  }

  Future<List<String>> getDocumentFiles() async {
    if (!await requestPermissions()) {
      throw Exception('Storage permission denied');
    }
    
    return await _getFilesByExtensions(documentExtensions);
  }

  Future<List<String>> getAllFiles() async {
    if (!await requestPermissions()) {
      throw Exception('Storage permission denied');
    }
    
    final imageFiles = await _getFilesByExtensions(imageExtensions);
    final documentFiles = await _getFilesByExtensions(documentExtensions);
    
    return [...imageFiles, ...documentFiles];
  }

  Future<List<String>> _getFilesByExtensions(List<String> extensions) async {
    final List<String> filePaths = [];
    
    try {
      // Get common directories
      final directories = await _getSearchDirectories();
      
      for (final directory in directories) {
        if (await directory.exists()) {
          await _scanDirectory(directory, extensions, filePaths);
        }
      }
    } catch (e) {
      print('Error scanning files: $e');
    }
    
    return filePaths;
  }

  Future<List<Directory>> _getSearchDirectories() async {
    final List<Directory> directories = [];
    
    try {
      // Internal storage directories
      final appDir = await getApplicationDocumentsDirectory();
      final extDir = await getExternalStorageDirectory();
      
      directories.add(appDir);
      if (extDir != null) {
        directories.add(extDir);
      }

      // Common Android directories
      const commonPaths = [
        '/storage/emulated/0/DCIM',
        '/storage/emulated/0/Pictures',
        '/storage/emulated/0/Downloads',
        '/storage/emulated/0/Documents',
        '/sdcard/DCIM',
        '/sdcard/Pictures',
        '/sdcard/Downloads',
        '/sdcard/Documents',
      ];

      for (final path in commonPaths) {
        final dir = Directory(path);
        if (await dir.exists()) {
          directories.add(dir);
        }
      }
    } catch (e) {
      print('Error getting directories: $e');
    }
    
    return directories;
  }

  Future<void> _scanDirectory(
  Directory directory,
  List<String> extensions,
  List<String> filePaths,
) async {
      try {
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        final extension = entity.path.split('.').last.toLowerCase();
        if (extensions.contains(extension)) {
          print("✅ Found image: ${entity.path}"); // <--- ADD THIS LINE
          filePaths.add(entity.path);
        }
      }
    }
  } catch (e) {
    print('❌ Error scanning directory ${directory.path}: $e');
  }
}

  Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (e) {
      print('Error deleting file $filePath: $e');
    }
    return false;
  }

  Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final stat = await file.stat();
        return stat.size;
      }
    } catch (e) {
      print('Error getting file size: $e');
    }
    return 0;
  }
}