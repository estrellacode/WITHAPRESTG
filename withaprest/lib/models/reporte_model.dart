enum FrecuenciaPrestamo { semanal, quincenal, mensual }

FrecuenciaPrestamo frecuenciaPrestamoFromDb(String value) {
  return FrecuenciaPrestamo.values.firstWhere(
    (e) => e.name == value,
    orElse: () => FrecuenciaPrestamo.semanal,
  );
}

class ReporteControlCobranzaRow {
  final String cuotaId;
  final String prestamoId;
  final String clienteId;
  final String codigo;
  final String nombreCliente;
  final FrecuenciaPrestamo frecuencia;
  final int numCuota;
  final DateTime? fechaVencimiento;
  final bool pagada;

  const ReporteControlCobranzaRow({
    required this.cuotaId,
    required this.prestamoId,
    required this.clienteId,
    required this.codigo,
    required this.nombreCliente,
    required this.frecuencia,
    required this.numCuota,
    required this.fechaVencimiento,
    required this.pagada,
  });

  factory ReporteControlCobranzaRow.fromMap(Map<String, dynamic> map) {
    return ReporteControlCobranzaRow(
      cuotaId: (map['cuota_id'] ?? '').toString(),
      prestamoId: (map['prestamo_id'] ?? '').toString(),
      clienteId: (map['cliente_id'] ?? '').toString(),
      codigo: (map['codigo'] ?? '').toString(),
      nombreCliente: (map['nombre_cliente'] ?? '').toString(),
      frecuencia: frecuenciaPrestamoFromDb(
        (map['frecuencia'] ?? 'semanal').toString(),
      ),
      numCuota: map['num_cuota'] is int
          ? map['num_cuota']
          : int.tryParse('${map['num_cuota']}') ?? 0,
      fechaVencimiento: map['fecha_vencimiento'] == null
          ? null
          : DateTime.tryParse(map['fecha_vencimiento'].toString()),
      pagada: map['pagada'] == true,
    );
  }

  ReporteControlCobranzaRow copyWith({bool? pagada}) {
    return ReporteControlCobranzaRow(
      cuotaId: cuotaId,
      prestamoId: prestamoId,
      clienteId: clienteId,
      codigo: codigo,
      nombreCliente: nombreCliente,
      frecuencia: frecuencia,
      numCuota: numCuota,
      fechaVencimiento: fechaVencimiento,
      pagada: pagada ?? this.pagada,
    );
  }
}
