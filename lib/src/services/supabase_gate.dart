import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/settings.dart';

class SupabaseGate {
  static bool get ready {
    try {
      return Supabase.instance.isInitialized;
    } catch (_) {
      return false;
    }
  }

  static SupabaseClient? get client {
    if (!ready) return null;
    return Supabase.instance.client;
  }

  static Future<String?> ensure(AppSettings settings) async {
    final url = settings.supabaseUrl.trim();
    final key = settings.supabaseAnonKey.trim();
    if (url.isEmpty || key.isEmpty) {
      return 'Add a Supabase URL and anon key.';
    }
    if (ready) return null;
    try {
      await Supabase.initialize(url: url, publishableKey: key);
      return null;
    } catch (error) {
      return 'Supabase did not start. $error';
    }
  }

  static String? currentEmail() => client?.auth.currentUser?.email;

  static String? currentUserId() => client?.auth.currentUser?.id;

  static String? accessToken() => client?.auth.currentSession?.accessToken;

  static Future<String?> signIn(String email, String password) async {
    final supabase = client;
    if (supabase == null) return 'Supabase is not initialized.';
    try {
      await supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on AuthException catch (error) {
      return error.message;
    } catch (error) {
      return 'Sign-in failed. $error';
    }
  }

  static Future<String?> signUp(String email, String password) async {
    final supabase = client;
    if (supabase == null) return 'Supabase is not initialized.';
    try {
      await supabase.auth.signUp(email: email.trim(), password: password);
      return null;
    } on AuthException catch (error) {
      return error.message;
    } catch (error) {
      return 'Could not create the account. $error';
    }
  }

  static Future<String?> sendMagicLink(String email) async {
    final supabase = client;
    if (supabase == null) return 'Supabase is not initialized.';
    try {
      await supabase.auth.signInWithOtp(
        email: email.trim(),
        emailRedirectTo: 'online.mucsarocsoge.xerno://login-callback',
      );
      return null;
    } on AuthException catch (error) {
      return error.message;
    } catch (error) {
      return 'Could not send the magic link. $error';
    }
  }

  static Future<String?> exchange(String codeOrUrl) async {
    final supabase = client;
    if (supabase == null) return 'Supabase is not initialized.';
    final code = _extractCode(codeOrUrl);
    if (code.isEmpty) return 'Paste the code from the email link.';
    try {
      await supabase.auth.exchangeCodeForSession(code);
      return null;
    } on AuthException catch (error) {
      return error.message;
    } catch (error) {
      return 'Could not exchange that code. $error';
    }
  }

  static Future<void> signOut() async {
    final supabase = client;
    if (supabase == null) return;
    await supabase.auth.signOut();
  }
}

String _extractCode(String raw) {
  final trimmed = raw.trim();
  final uri = Uri.tryParse(trimmed);
  final fromQuery = uri?.queryParameters['code'];
  if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;
  return trimmed;
}
