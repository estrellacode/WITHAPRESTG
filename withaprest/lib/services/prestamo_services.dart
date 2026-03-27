import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:withaprest/models/prestamo_model.dart';
import 'package:withaprest/models/registro_model.dart';

class PrestamoService {
  PrestamoService({SupabaseClient? client})
    : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;

  Future<PrestamoRow?> getPrestamoActivoCliente(String clienteId) async {
    final res = await _db
        .from('prestamos')
        .select('''
          id,
          cliente_id,
          tipo,
          frecuencia,
          estado,
          monto_total,
          numero_cuotas,
          monto_cuota,
          fecha_inicio,
          fecha_primer_vencimiento,
          prestamo_anterior_id,
          created_at
        ''')
        .eq('cliente_id', clienteId)
        .eq('estado', 'activo')
        .order('created_at', ascending: false)
        .limit(1);

    if (res is List && res.isNotEmpty) {
      return PrestamoRow.fromJson(res.first as Map<String, dynamic>);
    }
    return null;
  }

  Future<List<AvalRow>> listarAvalesCliente(String clienteId) async {
    final res = await _db
        .from('avales')
        .select('''
          id,
          cliente_id,
          nombre,
          apellido_paterno,
          apellido_materno,
          telefono,
          vialidad_tipo,
          vialidad_nombre,
          asentamiento_tipo,
          asentamiento_nombre,
          ciudad,
          estado,
          cp,
          clave_elector
        ''')
        .eq('cliente_id', clienteId)
        .order('created_at', ascending: true);

    if (res is! List) return [];

    return res.map((e) => AvalRow.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PrestamoRow> crearPrestamoConCuotas({
    required ClienteRow cliente,
    required double montoSolicitado,
    required int numeroCuotas,
    required FrecuenciaPrestamo frecuencia,
    required DateTime fechaPrimerPago,
    PrestamoRow? prestamoActivoAnterior,
    bool liquidarAnterior = false,
  }) async {
    final tipo = (prestamoActivoAnterior == null)
        ? TipoPrestamo.nuevo
        : TipoPrestamo.renovacion;

    // En BD se guarda el monto real
    final montoTotal = montoSolicitado;

    // La cuota real sale del monto real
    final montoCuota = _round2(montoTotal / numeroCuotas);

    if (liquidarAnterior && prestamoActivoAnterior != null) {
      await _db
          .from('prestamos')
          .update({'estado': 'liquidado'})
          .eq('id', prestamoActivoAnterior.id);
    }

    final insertPrestamo = {
      'cliente_id': cliente.id,
      'tipo': tipoToDb(tipo),
      'frecuencia': frecuenciaToDb(frecuencia),
      'estado': 'activo',
      'monto_total': montoTotal,
      'numero_cuotas': numeroCuotas,
      'monto_cuota': montoCuota,
      'fecha_inicio': asDate(DateTime.now()),
      'fecha_primer_vencimiento': asDate(fechaPrimerPago),
      'prestamo_anterior_id': prestamoActivoAnterior?.id,
    };

    final created = await _db.from('prestamos').insert(insertPrestamo).select(
      '''
          id,
          cliente_id,
          tipo,
          frecuencia,
          estado,
          monto_total,
          numero_cuotas,
          monto_cuota,
          fecha_inicio,
          fecha_primer_vencimiento,
          prestamo_anterior_id,
          created_at
        ''',
    ).single();

    final prestamo = PrestamoRow.fromJson(created as Map<String, dynamic>);

    final cuotas = _generarCuotas(
      fechaPrimerPago: fechaPrimerPago,
      frecuencia: frecuencia,
      numeroCuotas: numeroCuotas,
      montoCuota: prestamo.montoCuota,
    );

    final insertCuotas = cuotas
        .map((c) => c.toInsertJson(prestamoId: prestamo.id))
        .toList();

    await _db.from('cobranza_cuotas').insert(insertCuotas);

    return prestamo;
  }

  List<CuotaInsert> _generarCuotas({
    required DateTime fechaPrimerPago,
    required FrecuenciaPrestamo frecuencia,
    required int numeroCuotas,
    required double montoCuota,
  }) {
    final out = <CuotaInsert>[];
    var fecha = DateTime(
      fechaPrimerPago.year,
      fechaPrimerPago.month,
      fechaPrimerPago.day,
    );

    for (int i = 1; i <= numeroCuotas; i++) {
      out.add(
        CuotaInsert(
          numCuota: i,
          fechaVencimiento: fecha,
          montoCuota: montoCuota,
        ),
      );
      fecha = _nextDate(fecha, frecuencia);
    }
    return out;
  }

  DateTime _nextDate(DateTime d, FrecuenciaPrestamo f) {
    switch (f) {
      case FrecuenciaPrestamo.semanal:
        return d.add(const Duration(days: 7));
      case FrecuenciaPrestamo.quincenal:
        return d.add(const Duration(days: 15));
      case FrecuenciaPrestamo.mensual:
        return _addMonthsSafe(d, 1);
    }
  }

  DateTime _addMonthsSafe(DateTime d, int months) {
    final newMonth = d.month + months;
    final year = d.year + ((newMonth - 1) ~/ 12);
    final month = ((newMonth - 1) % 12) + 1;
    final day = min(d.day, _daysInMonth(year, month));
    return DateTime(year, month, day);
  }

  int _daysInMonth(int year, int month) {
    final next = (month == 12)
        ? DateTime(year + 1, 1, 1)
        : DateTime(year, month + 1, 1);
    return next.subtract(const Duration(days: 1)).day;
  }

  double _round2(double v) => (v * 100).round() / 100.0;
}
