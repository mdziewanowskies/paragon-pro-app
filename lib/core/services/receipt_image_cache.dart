import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class ReceiptImageCache {
  static String? _cacheDir;

  static Future<String> get _dir async {
    if (_cacheDir != null) return _cacheDir!;
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/receipt_images');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir.path;
    return _cacheDir!;
  }

  static String _fileNameFromUrl(String url) {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;
    if (segments.length >= 2) {
      return '${segments[segments.length - 2]}_${segments.last}';
    }
    return url.hashCode.toRadixString(16);
  }

  /// Save image bytes locally (called after upload)
  static Future<String> saveLocal(String imageUrl, Uint8List bytes) async {
    final dir = await _dir;
    final fileName = _fileNameFromUrl(imageUrl);
    final file = File('$dir/$fileName');
    await file.writeAsBytes(bytes);
    debugPrint('Image cached locally: $fileName (${bytes.length} bytes)');
    return file.path;
  }

  /// Get local file path if cached, null otherwise
  static Future<String?> getLocalPath(String imageUrl) async {
    if (imageUrl.isEmpty ||
        (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://'))) {
      return null;
    }

    final dir = await _dir;
    final fileName = _fileNameFromUrl(imageUrl);
    final file = File('$dir/$fileName');

    if (await file.exists()) {
      return file.path;
    }
    return null;
  }

  /// Get image: local-first, download if missing
  static Future<String?> getOrFetch(String imageUrl) async {
    if (imageUrl.isEmpty ||
        (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://'))) {
      return null;
    }

    // Check local cache first
    final localPath = await getLocalPath(imageUrl);
    if (localPath != null) {
      debugPrint('Image from cache: $localPath');
      return localPath;
    }

    // Download and cache
    try {
      debugPrint('Image fetch: $imageUrl');
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final path = await saveLocal(imageUrl, response.bodyBytes);
        return path;
      }
      debugPrint('Image fetch failed: ${response.statusCode} for $imageUrl');
      debugPrint('Response body: ${response.body.substring(0, response.body.length.clamp(0, 200))}');
    } catch (e) {
      debugPrint('Image fetch error: $e');
    }
    return null;
  }

  /// Clear all cached images
  static Future<void> clearCache() async {
    final dir = await _dir;
    final directory = Directory(dir);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
      await directory.create();
      _cacheDir = null;
      debugPrint('Image cache cleared');
    }
  }

  /// Get cache size in bytes
  static Future<int> getCacheSize() async {
    final dir = await _dir;
    final directory = Directory(dir);
    if (!await directory.exists()) return 0;

    int size = 0;
    await for (final entity in directory.list()) {
      if (entity is File) {
        size += await entity.length();
      }
    }
    return size;
  }
}
