import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // --- Profile & Settings ---

  Future<Map<String, dynamic>?> getProfile(String userId) async {
    try {
      return await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
    } catch (e) {
      print("Error fetching profile: $e");
      return null;
    }
  }

  Future<void> updateProfile({
    required String userId,
    String? name,
    String? imageUrl,
  }) async {
    final updates = {
      if (name != null) 'name': name,
      if (imageUrl != null) 'profile_image_url': imageUrl,
    };
    if (updates.isEmpty) return;

    await _supabase.from('profiles').update(updates).eq('id', userId);
  }

  Future<Map<String, dynamic>> getUserSettings(String userId) async {
    try {
      final data = await _supabase
          .from('user_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (data == null) {
        // Create default settings if not exists
        final defaultSettings = {
          'user_id': userId,
          'dark_mode': true,
          'auto_save_history': true,
          'notifications_enabled': true,
        };
        
        try {
          final inserted = await _supabase
              .from('user_settings')
              .insert(defaultSettings)
              .select()
              .single();
          return inserted;
        } catch (e) {
          print("Error creating default settings: $e");
          // If insert fails (e.g. RLS), return local defaults
          return defaultSettings;
        }
      }
      return data;
    } catch (e) {
      print("Error fetching settings: $e");
      return {
        'dark_mode': true,
        'auto_save_history': true,
        'notifications_enabled': true,
      };
    }
  }

  Future<void> updateSettings(String userId, Map<String, dynamic> updates) async {
    await _supabase.from('user_settings').update(updates).eq('user_id', userId);
  }

  // --- Scans ---

  Future<String> saveScan({
    required String userId,
    required String mediaUrl,
    required String result,
    required double confidence,
  }) async {
    final response = await _supabase.from('scans').insert({
      'user_id': userId,
      'media_url': mediaUrl,
      'result': result,
      'confidence': confidence,
    }).select().single();
    
    return response['id'];
  }

  Future<List<Map<String, dynamic>>> getScanHistory(String userId) async {
    try {
      final List<dynamic> data = await _supabase
          .from('scans')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print("Error fetching history: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> getStats(String userId) async {
    try {
      final scans = await _supabase
          .from('scans')
          .select('result')
          .eq('user_id', userId);
      
      int total = scans.length;
      int fakes = scans.where((s) => s['result'] == 'fake').length;

      return {
        'total_scans': total,
        'fake_detections': fakes,
      };
    } catch (e) {
      print("Error fetching stats: $e");
      return {
        'total_scans': 0,
        'fake_detections': 0,
      };
    }
  }

  // --- Reports ---

  Future<void> submitReport({
    required String userId,
    String? scanId,
    required String mediaUrl,
    required String predictedResult,
    required double confidence,
    required bool isIncorrect,
    required String feedbackText,
  }) async {
    await _supabase.from('reports').insert({
      'user_id': userId,
      'scan_id': scanId,
      'media_url': mediaUrl,
      'predicted_result': predictedResult,
      'confidence': confidence,
      'is_incorrect': isIncorrect,
      'feedback_text': feedbackText,
    });
  }

  // --- Storage ---

  Future<String?> uploadProfileImage(String userId, File imageFile) async {
    try {
      final fileExt = imageFile.path.split('.').last;
      final fileName = '$userId-profile.$fileExt';
      final filePath = 'profiles/$fileName';

      await _supabase.storage.from('avatars').upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );

      final String publicUrl = _supabase.storage.from('avatars').getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      print("Error uploading image: $e");
      return null;
    }
  }

  // --- Account Deletion ---

  Future<void> deleteAccount(String userId) async {
    // RLS and cascade deletes should handle scans and reports if configured in DB
    // But we'll call auth.signOut and the user can be deleted via admin/service role or triggers.
    // For client-side, we'll just trigger the deletion if we have a function or direct access.
    // Note: Supabase client cannot delete the user themselves easily without service role.
    // We'll assume the user triggers a deletion flow that might need a background function.
    // For this app, we'll just call a delete on the profiles table which is linked via cascade.
    await _supabase.from('profiles').delete().eq('id', userId);
    await _supabase.auth.signOut();
  }
}
