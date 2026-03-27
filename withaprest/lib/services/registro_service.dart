import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:withaprest/models/registro_model.dart';

class RegistroService {
  SupabaseClient get _sb => Supabase.instance.client;

  static const String _clienteSelectCompleto = '''
    id,
    codigo,
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
    clave_elector,
    avales(count)
  ''';

  static const String _avalSelectCompleto = '''
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
    clave_elector,
    created_at
  ''';

  Future<ClienteRow> crearClienteConCodigo(ClienteInput input) async {
    if (input.nombre.trim().isEmpty) {
      throw Exception('El nombre es obligatorio.');
    }
    if (input.apellidoPaterno.trim().isEmpty) {
      throw Exception('El apellido paterno es obligatorio.');
    }

    final resp = await _sb.rpc(
      'crear_cliente_con_codigo',
      params: {
        'p_nombre': input.nombre.trim(),
        'p_apellido_paterno': input.apellidoPaterno.trim(),
        'p_apellido_materno': (input.apellidoMaterno ?? '').trim().isEmpty
            ? null
            : input.apellidoMaterno!.trim(),
        'p_telefono': (input.telefono ?? '').trim().isEmpty
            ? null
            : input.telefono!.trim(),
        'p_vialidad_tipo': enumToDbVialidad(input.vialidadTipo),
        'p_vialidad_nombre': (input.vialidadNombre ?? '').trim().isEmpty
            ? null
            : input.vialidadNombre!.trim(),
        'p_asentamiento_tipo': enumToDbAsentamiento(input.asentamientoTipo),
        'p_asentamiento_nombre': (input.asentamientoNombre ?? '').trim().isEmpty
            ? null
            : input.asentamientoNombre!.trim(),
        'p_ciudad': (input.ciudad ?? '').trim().isEmpty
            ? null
            : input.ciudad!.trim(),
        'p_estado': (input.estado ?? '').trim().isEmpty
            ? null
            : input.estado!.trim(),
        'p_cp': (input.cp ?? '').trim().isEmpty ? null : input.cp!.trim(),
        'p_clave_elector': (input.claveElector ?? '').trim().isEmpty
            ? null
            : input.claveElector!.trim(),
      },
    );

    if (resp == null) {
      throw Exception('RPC crear_cliente_con_codigo regresó null.');
    }

    if (resp is Map) {
      return ClienteRow.fromJson(Map<String, dynamic>.from(resp));
    }

    if (resp is List) {
      if (resp.isEmpty) throw Exception('RPC regresó lista vacía.');
      final first = resp.first;
      if (first is! Map) {
        throw Exception('RPC regresó List pero no Map: ${first.runtimeType}');
      }
      return ClienteRow.fromJson(Map<String, dynamic>.from(first));
    }

    throw Exception('RPC regresó tipo inesperado: ${resp.runtimeType}');
  }

  Future<void> insertarAvales({
    required String clienteId,
    required List<AvalInput> avales,
  }) async {
    if (avales.isEmpty) return;

    if (avales.length > 10) {
      throw Exception('Máximo 10 avales.');
    }

    final payload = avales
        .map((a) => a.toInsertJson(clienteId: clienteId))
        .toList();

    await _sb.from('avales').insert(payload);
  }

  Future<List<ClienteRow>> buscarClientes(String q) async {
    final query = q.trim();
    if (query.isEmpty) return [];

    final onlyCodeChars = RegExp(r'^[A-Za-z0-9]+$').hasMatch(query);
    final looksLikeCode =
        onlyCodeChars && !query.contains(' ') && query.length <= 12;

    if (looksLikeCode) {
      final byCode = await _sb
          .from('clientes')
          .select(_clienteSelectCompleto)
          .ilike('codigo', '%$query%')
          .order('created_at', ascending: false)
          .limit(25);

      final list = (byCode as List)
          .map((e) => ClienteRow.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      if (list.isNotEmpty) return list;
    }

    final data = await _sb
        .from('clientes')
        .select(_clienteSelectCompleto)
        .or(
          'nombre.ilike.%$query%,'
          'apellido_paterno.ilike.%$query%,'
          'apellido_materno.ilike.%$query%',
        )
        .order('created_at', ascending: false)
        .limit(25);

    return (data as List)
        .map((e) => ClienteRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<ClienteRow>> listarClientesConAvalesCount({
    int limit = 50,
    int offset = 0,
    bool asc = true,
  }) async {
    final data = await _sb
        .from('clientes')
        .select(_clienteSelectCompleto)
        .order('nombre', ascending: asc)
        .order('apellido_paterno', ascending: asc)
        .order('apellido_materno', ascending: asc)
        .range(offset, offset + limit - 1);

    return (data as List)
        .map((e) => ClienteRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<ClienteRow>> buscarClientesConAvalesCount({
    required String q,
    bool asc = true,
    int limit = 50,
  }) async {
    final query = q.trim();
    if (query.isEmpty) return [];

    final onlyCodeChars = RegExp(r'^[A-Za-z0-9]+$').hasMatch(query);
    final looksLikeCode =
        onlyCodeChars && !query.contains(' ') && query.length <= 12;

    if (looksLikeCode) {
      final byCode = await _sb
          .from('clientes')
          .select(_clienteSelectCompleto)
          .ilike('codigo', '%$query%')
          .order('nombre', ascending: asc)
          .limit(limit);

      final list = (byCode as List)
          .map((e) => ClienteRow.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      if (list.isNotEmpty) return list;
    }

    final data = await _sb
        .from('clientes')
        .select(_clienteSelectCompleto)
        .or(
          'nombre.ilike.%$query%,'
          'apellido_paterno.ilike.%$query%,'
          'apellido_materno.ilike.%$query%',
        )
        .order('nombre', ascending: asc)
        .limit(limit);

    return (data as List)
        .map((e) => ClienteRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<AvalRow>> listarAvalesDeCliente({
    required String clienteId,
  }) async {
    final data = await _sb
        .from('avales')
        .select(_avalSelectCompleto)
        .eq('cliente_id', clienteId)
        .order('created_at', ascending: true);

    return (data as List)
        .map((e) => AvalRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
