import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import 'supabase_service.dart';

class StorageService {
  static SupabaseStorageClient get _storage => SupabaseService.storage;

  static Future<String> uploadReceipt({
    required String userId,
    required Uint8List fileBytes,
    String? fileName,
  }) async {
    final name =
        fileName ?? '${DateTime.now().millisecondsSinceEpoch}_receipt.jpg';
    final path = '$userId/$name';

    await _storage.from(AppConstants.receiptsBucket).uploadBinary(
          path,
          fileBytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    return _storage
        .from(AppConstants.receiptsBucket)
        .getPublicUrl(path);
  }

  static Future<void> deleteReceipt(String path) async {
    await _storage.from(AppConstants.receiptsBucket).remove([path]);
  }
}
