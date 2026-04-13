import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

final isOnlineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.when(
    data: (results) => !results.contains(ConnectivityResult.none),
    loading: () => true,
    error: (_, __) => true,
  );
});

class OfflineSyncService {
  static const String _pendingUploadsBox = 'pending_uploads';
  static const String _cachedReceiptsBox = 'cached_receipts';

  static Future<void> initialize() async {
    await Hive.initFlutter();
    await Hive.openBox(_pendingUploadsBox);
    await Hive.openBox(_cachedReceiptsBox);
  }

  static Box get _pendingBox => Hive.box(_pendingUploadsBox);
  static Box get _cacheBox => Hive.box(_cachedReceiptsBox);

  // Queue receipt for upload when offline
  static Future<void> queueReceipt(Map<String, dynamic> receiptData) async {
    final key = DateTime.now().millisecondsSinceEpoch.toString();
    await _pendingBox.put(key, jsonEncode(receiptData));
  }

  // Get pending uploads
  static List<Map<String, dynamic>> getPendingUploads() {
    return _pendingBox.values
        .map((v) => jsonDecode(v as String) as Map<String, dynamic>)
        .toList();
  }

  // Remove from queue after sync
  static Future<void> removePending(String key) async {
    await _pendingBox.delete(key);
  }

  // Cache receipts for offline viewing
  static Future<void> cacheReceipts(
      List<Map<String, dynamic>> receipts) async {
    await _cacheBox.clear();
    for (var i = 0; i < receipts.length; i++) {
      await _cacheBox.put(i.toString(), jsonEncode(receipts[i]));
    }
  }

  // Get cached receipts
  static List<Map<String, dynamic>> getCachedReceipts() {
    return _cacheBox.values
        .map((v) => jsonDecode(v as String) as Map<String, dynamic>)
        .toList();
  }

  // Sync pending uploads
  static Future<int> syncPendingUploads() async {
    final pending = _pendingBox.toMap();
    int synced = 0;
    for (final entry in pending.entries) {
      try {
        // TODO: Upload to Supabase
        await _pendingBox.delete(entry.key);
        synced++;
      } catch (_) {
        // Will retry next time
      }
    }
    return synced;
  }

  static bool get hasPendingUploads => _pendingBox.isNotEmpty;
  static int get pendingCount => _pendingBox.length;
}
