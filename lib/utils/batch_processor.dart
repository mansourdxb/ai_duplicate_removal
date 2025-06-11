import 'dart:async';
import 'package:photo_manager/photo_manager.dart';

typedef ProcessCallback = Future<void> Function(AssetEntity video);
typedef ProgressCallback = void Function(int processed, int total);

class BatchProcessor {
  static Future<void> processVideos({
    required List<AssetEntity> videos,
    required ProcessCallback processFunction,
    required ProgressCallback progressCallback,
    int batchSize = 20,
    Duration pauseBetweenBatches = const Duration(milliseconds: 100),
  }) async {
    if (videos.isEmpty) return;
    
    int processed = 0;
    
    for (int i = 0; i < videos.length; i += batchSize) {
      final end = (i + batchSize < videos.length) ? i + batchSize : videos.length;
      final batch = videos.sublist(i, end);
      
      await Future.wait(
        batch.map((video) async {
          try {
            await processFunction(video).timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                print('Processing timed out for video: ${video.id}');
              },
            );
          } catch (e) {
            print('Error processing video ${video.id}: $e');
          }
          
          processed++;
          progressCallback(processed, videos.length);
        }),
      );
      
      // Give the UI thread some time to breathe
      await Future.delayed(pauseBetweenBatches);
    }
  }
}
