import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    debugPrint('=== Supabase Init ===');
    debugPrint('URL: ${AppConstants.supabaseUrl}');
    debugPrint('Key length: ${AppConstants.supabaseAnonKey.length}');
    debugPrint('Key starts with: ${AppConstants.supabaseAnonKey.substring(0, 10)}...');
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
    debugPrint('Supabase initialized OK');
  }

  static GoTrueClient get auth => client.auth;
  static SupabaseStorageClient get storage => client.storage;

  // Edge function calls
  static Future<FunctionResponse> invokeFunction(
    String functionName, {
    Map<String, dynamic>? body,
  }) async {
    return await client.functions.invoke(
      functionName,
      body: body,
    );
  }

  // RPC calls
  static Future<dynamic> rpc(String functionName,
      {Map<String, dynamic>? params}) async {
    return await client.rpc(functionName, params: params);
  }
}
