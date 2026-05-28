// 对外接口：
// - UploadImageCompressor.compressForRecommendationUpload

import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

class CompressedUploadImage {
  const CompressedUploadImage({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String filename;
  final String mimeType;
}

class UploadImageCompressor {
  static const List<int> _maxEdges = [960, 800, 720, 640];
  static const List<int> _qualities = [60, 55, 50, 45, 40];
  static const int _targetBytes = 50 * 1024;

  /// [对外接口] 为联网推荐上传生成一份激进压缩图。
  Future<CompressedUploadImage> compressForRecommendationUpload(
    String imagePath,
  ) async {
    final sourceFile = File(imagePath);
    final originalBytes = await sourceFile.readAsBytes();
    final decoded = img.decodeImage(originalBytes);
    final filename = '${p.basenameWithoutExtension(imagePath)}.jpg';
    if (decoded == null) {
      return CompressedUploadImage(
        bytes: originalBytes,
        filename: filename,
        mimeType: 'image/jpeg',
      );
    }

    Uint8List? bestBytes;
    var bestLength = 1 << 62;

    for (final maxEdge in _maxEdges) {
      final resized = _resizeIfNeeded(decoded, maxEdge);
      for (final quality in _qualities) {
        final encoded = Uint8List.fromList(
          img.encodeJpg(resized, quality: quality),
        );
        if (encoded.lengthInBytes < bestLength) {
          bestLength = encoded.lengthInBytes;
          bestBytes = encoded;
        }
        if (encoded.lengthInBytes <= _targetBytes) {
          return CompressedUploadImage(
            bytes: encoded,
            filename: filename,
            mimeType: 'image/jpeg',
          );
        }
      }
    }

    return CompressedUploadImage(
      bytes: bestBytes ?? originalBytes,
      filename: filename,
      mimeType: 'image/jpeg',
    );
  }

  img.Image _resizeIfNeeded(img.Image source, int maxEdge) {
    final currentMaxEdge = source.width > source.height
        ? source.width
        : source.height;
    if (currentMaxEdge <= maxEdge) {
      return img.Image.from(source);
    }

    final scale = maxEdge / currentMaxEdge;
    final width = (source.width * scale).round().clamp(1, source.width);
    final height = (source.height * scale).round().clamp(1, source.height);
    return img.copyResize(
      source,
      width: width,
      height: height,
      interpolation: img.Interpolation.cubic,
    );
  }
}
