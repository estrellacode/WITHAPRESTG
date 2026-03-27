import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:withaprest/models/perfil_model.dart';

class PerfilService {
  final SupabaseClient _sb = Supabase.instance.client;

  Future<ProfileModel?> obtenerPerfilActual() async {
    final user = _sb.auth.currentUser;
    if (user == null) return null;

    final data = await _sb
        .from('profiles')
        .select('id, rol, nombre, created_at')
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) return null;
    if (data is! Map) {
      throw Exception('profiles.maybeSingle() regresó ${data.runtimeType}');
    }
    return ProfileModel.fromMap(Map<String, dynamic>.from(data));
  }
}
