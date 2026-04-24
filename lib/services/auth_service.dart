import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<bool> signUpWithEmail(String email, String password, String name) async {
    try {
      final AuthResponse res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );

      final user = res.user;
      if (user != null) {
        try {
          await _supabase.from('users').insert({
            'id': user.id,
            'name': name,
            'email': email,
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (dbError) {
          print("Database insert skipped: $dbError");
        }
        return true;
      }
      return false;
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('rate limit')) {
        throw Exception("Rate limit exceeded. Please wait a few minutes, or disable 'Email Confirmations' in your Supabase Dashboard to test freely.");
      }
      throw Exception(e.message);
    } catch (e) {
      throw Exception("An unexpected error occurred: $e");
    }
  }

  Future<bool> signInWithEmail(String email, String password) async {
    try {
      final AuthResponse res = await _supabase.auth.signInWithPassword(
        email: email, 
        password: password
      );
      return res.user != null;
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('email not confirmed')) {
        throw Exception("Email not confirmed. Please check your inbox or disable 'Confirm email' in Supabase Dashboard (Auth -> Providers -> Email).");
      }
      throw Exception(e.message);
    } catch (e) {
      throw Exception("An unexpected error occurred: $e");
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
