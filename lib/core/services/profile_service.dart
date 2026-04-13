import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/data/profile_model.dart';
import 'supabase_service.dart';

final profileProvider =
    AsyncNotifierProvider<ProfileNotifier, ProfileModel?>(ProfileNotifier.new);

class ProfileNotifier extends AsyncNotifier<ProfileModel?> {
  @override
  Future<ProfileModel?> build() async {
    final user = SupabaseService.auth.currentUser;
    if (user == null) return null;
    return await _fetchProfile(user.id);
  }

  Future<ProfileModel?> _fetchProfile(String userId) async {
    try {
      final data = await SupabaseService.client
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (data == null) return null;
      return ProfileModel.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    final user = SupabaseService.auth.currentUser;
    if (user == null) return;

    updates['updated_at'] = DateTime.now().toIso8601String();

    await SupabaseService.client
        .from('profiles')
        .update(updates)
        .eq('user_id', user.id);

    state = AsyncData(await _fetchProfile(user.id));
  }

  Future<void> completeProfile(Map<String, dynamic> profileData) async {
    final user = SupabaseService.auth.currentUser;
    if (user == null) return;

    profileData['profile_completed'] = true;
    profileData['updated_at'] = DateTime.now().toIso8601String();

    // Try update first, then upsert
    final existing = await SupabaseService.client
        .from('profiles')
        .select('id')
        .eq('user_id', user.id)
        .maybeSingle();

    if (existing != null) {
      await SupabaseService.client
          .from('profiles')
          .update(profileData)
          .eq('user_id', user.id);
    } else {
      profileData['user_id'] = user.id;
      profileData['created_at'] = DateTime.now().toIso8601String();
      await SupabaseService.client.from('profiles').insert(profileData);
    }

    state = AsyncData(await _fetchProfile(user.id));
  }

  Future<void> saveKsefToken(String nip, String token) async {
    await updateProfile({
      'ksef_nip': nip,
      'ksef_token': token,
      'ksef_token_added_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> refresh() async {
    final user = SupabaseService.auth.currentUser;
    if (user == null) {
      state = const AsyncData(null);
      return;
    }
    state = AsyncData(await _fetchProfile(user.id));
  }
}
