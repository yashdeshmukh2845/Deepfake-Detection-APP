import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// This class handles Login, Signup, and Logout logic using Supabase
class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Create a new account
  Future<bool> signUpWithEmail(String email, String password, String name) async {
    try {
      // 1. Sign up user via Supabase Auth
      final AuthResponse res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name}, // Stores extra metadata
      );

      final user = res.user;
      if (user != null) {
        // 2. Insert into the public users table for app queries (Silent try-catch so it doesn't block Auth)
        try {
          await _supabase.from('users').insert({
            'id': user.id,
            'name': name,
            'email': email,
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (dbError) {
          print("Database insert skipped: $dbError"); // Usually fails if 'users' table is missing or RLS blocks it.
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

  // Check credentials and start a session
  Future<bool> signInWithEmail(String email, String password) async {
    try {
      // Login via Supabase
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

  // Clear session data to logout
  Future<void> signOut() async {
    // 1. Log out of Supabase
    await _supabase.auth.signOut();
    
    // 2. Clear any local SharedPreferences data if needed
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
