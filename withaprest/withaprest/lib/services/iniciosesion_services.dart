import 'package:supabase_flutter/supabase_flutter.dart';

class InicioSesionService {
  final SupabaseClient _sb = Supabase.instance.client;

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    return _sb.auth.signInWithPassword(email: email, password: password);
  }

  Future<Map<String, dynamic>?> obtenerPerfil() async {
    final user = _sb.auth.currentUser;
    if (user == null) return null;

    final data = await _sb
        .from('profiles')
        .select('rol, nombre')
        .eq('id', user.id)
        .maybeSingle();

    return data;
  }

  Future<void> logout() async {
    await _sb.auth.signOut();
  }
}
