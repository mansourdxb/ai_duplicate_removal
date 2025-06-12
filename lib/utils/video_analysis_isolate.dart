import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

// Message class for communication between isolate and main thread
class VideoAnalysisMessage {
  final List<AssetEntity> videos;
  final SendPort sendPort;

  VideoAnalysisMessage(this.videos, this.sendPort);
}

// Result class for sending results back to main thread
class VideoAnalysisResult {
  final List<List<AssetEntity>> duplicateGroups;
  final int processedCount;
  final bool isComplete;

  VideoAnalysisResult(this.duplicateGroups, this.processedCount, this.isComplete);
}
// Function to start the isolate
Future<ReceivePort> startVideoAnalysisIsolate(List<AssetEntity> videos) async {
  final ReceivePort receivePort = ReceivePort();
  await Isolate.spawn(
    _videoAnalysisIsolateEntryPoint,
    VideoAnalysisMessage(videos, receivePort.sendPort),
  );
  return receivePort;
}

// The entry point for the isolate
void _videoAnalysisIsolateEntryPoint(VideoAnalysisMessage message) async {
  final videos = message.videos;
  final sendPort = message.sendPort;
  
  final List<List<AssetEntity>> duplicateGroups = [];
  
  // Group videos by duration first (within 1-second tolerance)
  final Map<int, List<AssetEntity>> durationGroups = {};
  
  for (int i = 0; i < videos.length; i++) {
    final video = videos[i];
    
    try {
      // Process in batches of 20 videos
      if (i % 20 == 0 && i > 0) {
        // Send progress update
        sendPort.send(VideoAnalysisResult(duplicateGroups, i, false));
        // Give the system a small break
        await Future.delayed(Duration(milliseconds: 50));
      }
      
      final duration = video.duration;
      final durationKey = (duration / 1000).round(); // Round to nearest second
      
      if (!durationGroups.containsKey(durationKey)) {
        durationGroups[durationKey] = [];
      }
      durationGroups[durationKey]!.add(video);
      
      // Send progress update every 10 videos
      if (i % 10 == 0) {
        sendPort.send(VideoAnalysisResult(duplicateGroups, i, false));
      }
    } catch (e) {
      print('Error processing video ${video.id}: $e');
      continue;
    }
  }
  
  // Now analyze each duration group for actual duplicates
  for (final durationKey in durationGroups.keys) {
    final videoGroup = durationGroups[durationKey]!;
    
    // Only analyze groups with more than one video
    if (videoGroup.length > 1) {
      // Your duplicate detection algorithm here
      // This is a simplified example - you'll need to replace with your actual algorithm
      final List<List<AssetEntity>> groupDuplicates = _findDuplicatesInGroup(videoGroup);
      duplicateGroups.addAll(groupDuplicates);
    }
  }
  
  // Send final result
  sendPort.send(VideoAnalysisResult(duplicateGroups, videos.length, true));
}

// Replace this with your actual duplicate detection algorithm
List<List<AssetEntity>> _findDuplicatesInGroup(List<AssetEntity> videoGroup) {
  // This is a placeholder for your actual algorithm
  // For example, comparing file sizes, creation dates, etc.
  
  final List<List<AssetEntity>> result = [];
  
  // Simple example: group by file size (within 5% tolerance)
  final Map<int, List<AssetEntity>> sizeGroups = {};
  
for (final video in videoGroup) {
  // Option 1: Use width
  final sizeKey = (video.size.width / 1024).round();
  
  // Option 2: Use height
  // final sizeKey = (video.size.height / 1024).round();
  
  // Option 3: Use area (width * height)
  // final sizeKey = ((video.size.width * video.size.height) / 1024).round();
  
  if (!sizeGroups.containsKey(sizeKey)) {
    sizeGroups[sizeKey] = [];
  }
  sizeGroups[sizeKey]!.add(video);
}


  // Add groups with more than one video as potential duplicates
  for (final sizeKey in sizeGroups.keys) {
    if (sizeGroups[sizeKey]!.length > 1) {
      result.add(sizeGroups[sizeKey]!);
    }
  }
  
  return result;
}
