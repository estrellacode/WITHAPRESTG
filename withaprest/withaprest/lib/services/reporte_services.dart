import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:withaprest/models/reporte_model.dart';

class ReporteControlCobranzaService {
  ReporteControlCobranzaService({SupabaseClient? client})
    : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;

  Future<List<ReporteControlCobranzaRow>> listarPorFecha(DateTime fecha) async {
    final fechaTxt = fecha.toIso8601String().split('T').first;

    final res = await _db
        .from('v_reporte_control_cobranza')
        .select('''
          cuota_id,
          prestamo_id,
          cliente_id,
          codigo,
          nombre_cliente,
          frecuencia,
          num_cuota,
          total_cuotas,
          fecha_vencimiento,
          monto_cuota,
          pagada
        ''')
        .eq('fecha_vencimiento', fechaTxt)
        .order('codigo', ascending: true);

    if (res is! List) return [];

    return res
        .map(
          (e) => ReporteControlCobranzaRow.fromMap(e as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> actualizarPagada({
    required String cuotaId,
    required bool pagada,
  }) async {
    await _db
        .from('cobranza_cuotas')
        .update({'pagada': pagada})
        .eq('id', cuotaId);
  }
}
