enum FrecuenciaPrestamo { semanal, quincenal, mensual }

FrecuenciaPrestamo frecuenciaPrestamoFromDb(String value) {
  return FrecuenciaPrestamo.values.firstWhere(
    (e) => e.name == value,
    orElse: () => FrecuenciaPrestamo.semanal,
  );
}

class ListaCobranzaRow {
  final String prestamoId;
  final String codigo;
  final String nombreCliente;
  final FrecuenciaPrestamo frecuencia;
  final String estado;
  final String? domicilio;

  final int cuotaActual;
  final DateTime? venceActual;
  final double aAbonar;
  final double saldoCuotaActual;
  final int cuotasAtrasadas;
  final int diasAtrasados;

  const ListaCobranzaRow({
    required this.prestamoId,
    required this.codigo,
    required this.nombreCliente,
    required this.frecuencia,
    required this.estado,
    required this.domicilio,
    required this.cuotaActual,
    required this.venceActual,
    required this.aAbonar,
    required this.saldoCuotaActual,
    required this.cuotasAtrasadas,
    required this.diasAtrasados,
  });

  factory ListaCobranzaRow.fromMap(Map<String, dynamic> map) {
    double toDouble(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    DateTime? toDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return ListaCobranzaRow(
      prestamoId: (map['prestamo_id'] ?? '').toString(),
      codigo: (map['codigo'] ?? '').toString(),
      nombreCliente: (map['nombre_cliente'] ?? '').toString(),
      frecuencia: frecuenciaPrestamoFromDb(
        (map['frecuencia'] ?? 'semanal').toString(),
      ),
      estado: (map['estado'] ?? '').toString(),
      domicilio: map['domicilio']?.toString(),
      cuotaActual: toInt(map['cuota_actual']),
      venceActual: toDate(map['vence_actual']),
      aAbonar: toDouble(map['a_abonar']),
      saldoCuotaActual: toDouble(map['saldo_cuota_actual']),
      cuotasAtrasadas: toInt(map['cuotas_atrasadas']),
      diasAtrasados: toInt(map['dias_atrasados']),
    );
  }
}
