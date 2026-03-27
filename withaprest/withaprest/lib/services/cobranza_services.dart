import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:withaprest/models/cobranza_model.dart';

class ListaCobranzaService {
  ListaCobranzaService({SupabaseClient? client})
    : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;

  Future<List<ListaCobranzaRow>> listar({
    String? query,
    bool soloAtrasados = false,
  }) async {
    dynamic req = _db.from('v_lista_cobranza').select('''
      prestamo_id,
      codigo,
      nombre_cliente,
      frecuencia,
      estado,
      domicilio,
      cuota_actual,
      vence_actual,
      a_abonar,
      saldo_cuota_actual,
      cuotas_atrasadas,
      dias_atrasados
    ''');

    if (soloAtrasados) {
      req = req.gt('dias_atrasados', 0);
    }

    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim();
      req = req.or('codigo.ilike.%$q%,nombre_cliente.ilike.%$q%');
    }

    final res = await req
        .order('dias_atrasados', ascending: false)
        .order('cuota_actual', ascending: true);

    if (res is! List) return [];

    return res
        .map((e) => ListaCobranzaRow.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }
}
