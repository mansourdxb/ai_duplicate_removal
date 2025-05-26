import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import '../models/duplicate_item.dart';

class DuplicateDetector {
  Future<List<List<DuplicateItem>>> findDuplicates(
    List<String> filePaths,
    {Function(String)? onProgress}
  ) async {
    final Map<String, List<DuplicateItem>> hashGroups = {};
    final List<List<DuplicateItem>> duplicateGroups = [];
    
    // Process files and group by hash
    for (int i = 0; i < filePaths.length; i++) {
      final filePath = filePaths[i];
      onProgress?.call('Processing ${i + 1}/${filePaths.length}: ${filePath.split('/').last}');
      
      try {
        final file = File(filePath);
        if (!await file.exists()) continue;
        
        final hash = await _calculateFileHash(file);
        final duplicateItem = DuplicateItem.fromFile(file, hash);
        
        if (hashGroups.containsKey(hash)) {
          hashGroups[hash]!.add(duplicateItem);
        } else {
          hashGroups[hash] = [duplicateItem];
        }
      } catch (e) {
        print('Error processing file $filePath: $e');
      }
    }
    
    // Find groups with more than one file (duplicates)
    for (final group in hashGroups.values) {
      if (group.length > 1) {
        duplicateGroups.add(group);
      }
    }
    
    // For images, also check for visual similarity
    onProgress?.call('Analyzing visual similarities...');
    final similarGroups = await _findSimilarImages(filePaths, onProgress);
    duplicateGroups.addAll(similarGroups);
    
    return duplicateGroups;
  }

  Future<String> _calculateFileHash(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      print('Error calculating hash for ${file.path}: $e');
      // Return a unique hash for files that can't be processed
      return 'error_${file.path.hashCode}';
    }
  }

  Future<List<List<DuplicateItem>>> _findSimilarImages(
    List<String> filePaths,
    Function(String)? onProgress,
  ) async {
    final List<List<DuplicateItem>> similarGroups = [];
    final List<ImageFingerprint> fingerprints = [];
    
    // Generate fingerprints for images
    final imageFiles = filePaths.where((path) => _isImageFile(path)).toList();
    
    for (int i = 0; i < imageFiles.length; i++) {
      final filePath = imageFiles[i];
      onProgress?.call('Analyzing image ${i + 1}/${imageFiles.length}');
      
      try {
        final fingerprint = await _generateImageFingerprint(filePath);
        if (fingerprint != null) {
          fingerprints.add(fingerprint);
        }
      } catch (e) {
        print('Error processing image $filePath: $e');
      }
    }
    
    // Compare fingerprints to find similar images
    final Set<int> processed = {};
    
    for (int i = 0; i < fingerprints.length; i++) {
      if (processed.contains(i)) continue;
      
      final List<DuplicateItem> similarItems = [];
      final baseFingerprint = fingerprints[i];
      
      for (int j = i; j < fingerprints.length; j++) {
        if (processed.contains(j)) continue;
        
        final similarity = _calculateSimilarity(
          baseFingerprint.hash,
          fingerprints[j].hash,
        );
        
        if (similarity > 0.85) { // 85% similarity threshold
          final file = File(fingerprints[j].filePath);
          final fileHash = await _calculateFileHash(file);
          final item = DuplicateItem.fromFile(
            file,
            fileHash,
            similarity: similarity,
          );
          similarItems.add(item);
          processed.add(j);
        }
      }
      
      if (similarItems.length > 1) {
        similarGroups.add(similarItems);
      }
    }
    
    return similarGroups;
  }

  bool _isImageFile(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension);
  }

  Future<ImageFingerprint?> _generateImageFingerprint(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) return null;
      
      // Resize to 8x8 for perceptual hash
      final resized = img.copyResize(image, width: 8, height: 8);
      final grayscale = img.grayscale(resized);
      
      // Calculate average pixel value
      int totalValue = 0;
      for (int y = 0; y < 8; y++) {
        for (int x = 0; x < 8; x++) {
          final pixel = img.getPixel(grayscale, x, y);
          totalValue += img.getRed(pixel);
        }
      }
      final average = totalValue / 64;
      
      // Generate hash based on pixel comparison to average
      String hash = '';
      for (int y = 0; y < 8; y++) {
        for (int x = 0; x < 8; x++) {
          final pixel = img.getPixel(grayscale, x, y);
          hash += img.getRed(pixel) > average ? '1' : '0';
        }
      }
      
      return ImageFingerprint(filePath: filePath, hash: hash);
    } catch (e) {
      print('Error generating fingerprint for $filePath