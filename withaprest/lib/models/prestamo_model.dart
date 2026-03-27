import 'package:flutter/foundation.dart';

enum FrecuenciaPrestamo { semanal, quincenal, mensual }

enum TipoPrestamo { nuevo, renovacion }

enum EstadoPrestamo { activo, liquidado, cancelado }

FrecuenciaPrestamo frecuenciaFromDb(String v) =>
    FrecuenciaPrestamo.values.firstWhere((e) => e.name == v);

TipoPrestamo tipoFromDb(String v) =>
    TipoPrestamo.values.firstWhere((e) => e.name == v);

EstadoPrestamo estadoFromDb(String v) =>
    EstadoPrestamo.values.firstWhere((e) => e.name == v);

String frecuenciaToDb(FrecuenciaPrestamo v) => v.name;
String tipoToDb(TipoPrestamo v) => v.name;
String estadoToDb(EstadoPrestamo v) => v.name;

String asDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

@immutable
class PrestamoRow {
  final String id;
  final String clienteId;

  final TipoPrestamo tipo;
  final FrecuenciaPrestamo frecuencia;
  final EstadoPrestamo estado;

  final double montoTotal; // monto real guardado en BD
  final int numeroCuotas;
  final double montoCuota;

  final DateTime fechaInicio; // date
  final DateTime fechaPrimerVencimiento; // date

  final String? prestamoAnteriorId;
  final DateTime createdAt;

  const PrestamoRow({
    required this.id,
    required this.clienteId,
    required this.tipo,
    required this.frecuencia,
    required this.estado,
    required this.montoTotal,
    required this.numeroCuotas,
    required this.montoCuota,
    required this.fechaInicio,
    required this.fechaPrimerVencimiento,
    required this.prestamoAnteriorId,
    required this.createdAt,
  });

  factory PrestamoRow.fromJson(Map<String, dynamic> json) => PrestamoRow(
    id: json['id'] as String,
    clienteId: json['cliente_id'] as String,
    tipo: tipoFromDb(json['tipo'] as String),
    frecuencia: frecuenciaFromDb(json['frecuencia'] as String),
    estado: estadoFromDb(json['estado'] as String),
    montoTotal: (json['monto_total'] as num).toDouble(),
    numeroCuotas: (json['numero_cuotas'] as num).toInt(),
    montoCuota: (json['monto_cuota'] as num).toDouble(),
    fechaInicio: DateTime.parse(json['fecha_inicio'] as String),
    fechaPrimerVencimiento: DateTime.parse(
      json['fecha_primer_vencimiento'] as String,
    ),
    prestamoAnteriorId: json['prestamo_anterior_id'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

@immutable
class CuotaInsert {
  final int numCuota;
  final DateTime fechaVencimiento;
  final double montoCuota;

  const CuotaInsert({
    required this.numCuota,
    required this.fechaVencimiento,
    required this.montoCuota,
  });

  Map<String, dynamic> toInsertJson({required String prestamoId}) => {
    'prestamo_id': prestamoId,
    'num_cuota': numCuota,
    'fecha_vencimiento': asDate(fechaVencimiento),
    'monto_cuota': montoCuota,
    'monto_pagado_acumulado': 0,
    'pagada': false,
  };
}
