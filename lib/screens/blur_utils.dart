import 'package:image/image.dart' as img;
import 'dart:typed_data';

bool computeBlurriness(Uint8List thumbBytes) {
  final image = img.decodeImage(thumbBytes);
  if (image == null) return false;

  final grayscale = img.grayscale(image);
  final laplacian = [
    [0, 1, 0],
    [1, -4, 1],
    [0, 1, 0],
  ];

  final width = grayscale.width;
  final height = grayscale.height;

  double sum = 0;
  double sumSq = 0;
  int count = 0;

  for (int y = 1; y < height - 1; y++) {
    for (int x = 1; x < width - 1; x++) {
      double value = 0;
      for (int ky = 0; ky < 3; ky++) {
        for (int kx = 0; kx < 3; kx++) {
          int px = x + kx - 1;
          int py = y + ky - 1;
          final pixelVal = grayscale.getPixel(px, py).luminance.toDouble();

          value += pixelVal * laplacian[ky][kx];
        }
      }
      sum += value;
      sumSq += value * value;
      count++;
    }
  }

  double mean = sum / count;
  double variance = (sumSq / count) - (mean * mean);
  return variance < 100.0;
}
