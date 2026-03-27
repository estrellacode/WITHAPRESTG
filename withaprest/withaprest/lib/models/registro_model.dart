// registro_models.dart
import 'package:flutter/foundation.dart';

enum TipoVialidad { calle, circuito, privada }

enum TipoAsentamiento { colonia, fraccionamiento }

String? enumToDbVialidad(TipoVialidad? v) => v?.name;
String? enumToDbAsentamiento(TipoAsentamiento? v) => v?.name;

TipoVialidad? vialidadFromDb(String? v) {
  if (v == null) return null;
  return TipoVialidad.values.firstWhere(
    (e) => e.name == v,
    orElse: () => TipoVialidad.calle,
  );
}

TipoAsentamiento? asentamientoFromDb(String? v) {
  if (v == null) return null;
  return TipoAsentamiento.values.firstWhere(
    (e) => e.name == v,
    orElse: () => TipoAsentamiento.colonia,
  );
}

@immutable
class ClienteInput {
  final String nombre;
  final String apellidoPaterno;
  final String? apellidoMaterno;
  final String? telefono;

  final TipoVialidad? vialidadTipo;
  final String? vialidadNombre;

  final TipoAsentamiento? asentamientoTipo;
  final String? asentamientoNombre;

  final String? ciudad;
  final String? estado;
  final String? cp;
  final String? claveElector;

  const ClienteInput({
    required this.nombre,
    required this.apellidoPaterno,
    this.apellidoMaterno,
    this.telefono,
    this.vialidadTipo,
    this.vialidadNombre,
    this.asentamientoTipo,
    this.asentamientoNombre,
    this.ciudad,
    this.estado,
    this.cp,
    this.claveElector,
  });
}

@immutable
class ClienteRow {
  final String id;
  final String codigo;

  final String nombre;
  final String apellidoPaterno;
  final String? apellidoMaterno;
  final String? telefono;
  final int avalesCount;

  final TipoVialidad? vialidadTipo;
  final String? vialidadNombre;
  final TipoAsentamiento? asentamientoTipo;
  final String? asentamientoNombre;
  final String? ciudad;
  final String? estado;
  final String? cp;
  final String? claveElector;

  const ClienteRow({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.apellidoPaterno,
    required this.apellidoMaterno,
    this.telefono,
    this.avalesCount = 0,
    this.vialidadTipo,
    this.vialidadNombre,
    this.asentamientoTipo,
    this.asentamientoNombre,
    this.ciudad,
    this.estado,
    this.cp,
    this.claveElector,
  });

  factory ClienteRow.fromJson(Map<String, dynamic> json) {
    int count = 0;

    final a = json['avales'];
    if (a is List && a.isNotEmpty) {
      final first = a.first;
      if (first is Map && first['count'] != null) {
        count = (first['count'] as num).toInt();
      }
    }

    return ClienteRow(
      id: json['id'] as String,
      codigo: (json['codigo'] ?? '') as String,
      nombre: (json['nombre'] ?? '') as String,
      apellidoPaterno: (json['apellido_paterno'] ?? '') as String,
      apellidoMaterno: json['apellido_materno'] as String?,
      telefono: json['telefono'] as String?,
      avalesCount: count,
      vialidadTipo: vialidadFromDb(json['vialidad_tipo'] as String?),
      vialidadNombre: json['vialidad_nombre'] as String?,
      asentamientoTipo: asentamientoFromDb(
        json['asentamiento_tipo'] as String?,
      ),
      asentamientoNombre: json['asentamiento_nombre'] as String?,
      ciudad: json['ciudad'] as String?,
      estado: json['estado'] as String?,
      cp: json['cp'] as String?,
      claveElector: json['clave_elector'] as String?,
    );
  }

  String get nombreCompleto {
    final am = (apellidoMaterno ?? '').trim();
    return '${nombre.trim()} ${apellidoPaterno.trim()}${am.isEmpty ? '' : ' $am'}';
  }
}

@immutable
class AvalInput {
  final String nombre;
  final String apellidoPaterno;
  final String? apellidoMaterno;
  final String? telefono;

  final TipoVialidad? vialidadTipo;
  final String? vialidadNombre;

  final TipoAsentamiento? asentamientoTipo;
  final String? asentamientoNombre;

  final String? ciudad;
  final String? estado;
  final String? cp;
  final String? claveElector;

  const AvalInput({
    required this.nombre,
    required this.apellidoPaterno,
    this.apellidoMaterno,
    this.telefono,
    this.vialidadTipo,
    this.vialidadNombre,
    this.asentamientoTipo,
    this.asentamientoNombre,
    this.ciudad,
    this.estado,
    this.cp,
    this.claveElector,
  });

  String get nombreCorto {
    final am = (apellidoMaterno ?? '').trim();
    return '${nombre.trim()} ${apellidoPaterno.trim()}${am.isEmpty ? '' : ' $am'}';
  }

  Map<String, dynamic> toInsertJson({required String clienteId}) => {
    'cliente_id': clienteId,
    'nombre': nombre.trim(),
    'apellido_paterno': apellidoPaterno.trim(),
    'apellido_materno': (apellidoMaterno ?? '').trim().isEmpty
        ? null
        : apellidoMaterno!.trim(),
    'telefono': (telefono ?? '').trim().isEmpty ? null : telefono!.trim(),
    'vialidad_tipo': enumToDbVialidad(vialidadTipo),
    'vialidad_nombre': (vialidadNombre ?? '').trim().isEmpty
        ? null
        : vialidadNombre!.trim(),
    'asentamiento_tipo': enumToDbAsentamiento(asentamientoTipo),
    'asentamiento_nombre': (asentamientoNombre ?? '').trim().isEmpty
        ? null
        : asentamientoNombre!.trim(),
    'ciudad': (ciudad ?? '').trim().isEmpty ? null : ciudad!.trim(),
    'estado': (estado ?? '').trim().isEmpty ? null : estado!.trim(),
    'cp': (cp ?? '').trim().isEmpty ? null : cp!.trim(),
    'clave_elector': (claveElector ?? '').trim().isEmpty
        ? null
        : claveElector!.trim(),
  };
}

@immutable
class AvalRow {
  final String id;
  final String clienteId;

  final String nombre;
  final String apellidoPaterno;
  final String? apellidoMaterno;
  final String? telefono;

  final TipoVialidad? vialidadTipo;
  final String? vialidadNombre;
  final TipoAsentamiento? asentamientoTipo;
  final String? asentamientoNombre;
  final String? ciudad;
  final String? estado;
  final String? cp;
  final String? claveElector;

  const AvalRow({
    required this.id,
    required this.clienteId,
    required this.nombre,
    required this.apellidoPaterno,
    this.apellidoMaterno,
    this.telefono,
    this.vialidadTipo,
    this.vialidadNombre,
    this.asentamientoTipo,
    this.asentamientoNombre,
    this.ciudad,
    this.estado,
    this.cp,
    this.claveElector,
  });

  factory AvalRow.fromJson(Map<String, dynamic> json) {
    return AvalRow(
      id: json['id'] as String,
      clienteId: json['cliente_id'] as String,
      nombre: (json['nombre'] ?? '') as String,
      apellidoPaterno: (json['apellido_paterno'] ?? '') as String,
      apellidoMaterno: json['apellido_materno'] as String?,
      telefono: json['telefono'] as String?,
      vialidadTipo: vialidadFromDb(json['vialidad_tipo'] as String?),
      vialidadNombre: json['vialidad_nombre'] as String?,
      asentamientoTipo: asentamientoFromDb(
        json['asentamiento_tipo'] as String?,
      ),
      asentamientoNombre: json['asentamiento_nombre'] as String?,
      ciudad: json['ciudad'] as String?,
      estado: json['estado'] as String?,
      cp: json['cp'] as String?,
      claveElector: json['clave_elector'] as String?,
    );
  }

  String get nombreCompleto {
    final am = (apellidoMaterno ?? '').trim();
    return '${nombre.trim()} ${apellidoPaterno.trim()}${am.isEmpty ? '' : ' $am'}';
  }
}
