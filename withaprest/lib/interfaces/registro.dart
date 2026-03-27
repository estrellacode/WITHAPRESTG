// registro.dart
import 'package:flutter/material.dart';
import 'package:withaprest/models/registro_model.dart';
import 'package:withaprest/services/registro_service.dart';
import 'package:withaprest/theme/iniciotema.dart';

class RegistroPage extends StatefulWidget {
  final ClienteRow? clienteInicial;
  final bool abrirFormularioAval;

  const RegistroPage({
    super.key,
    this.clienteInicial,
    this.abrirFormularioAval = false,
  });

  @override
  State<RegistroPage> createState() => _RegistroPageState();
}

class _RegistroPageState extends State<RegistroPage> {
  final _svc = RegistroService();

  // =========================
  // AVALES (BD + NUEVOS)
  // =========================
  bool _loadingAvales = false;
  List<AvalRow> _avalesBD = [];
  final List<AvalInput> _avalesNuevos = [];
  bool _savingAvales = false;

  // =========================
  // Step
  // =========================
  int _step = 0;

  // =========================
  // Cliente form
  // =========================
  final _formClienteKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _apPatCtrl = TextEditingController();
  final _apMatCtrl = TextEditingController();
  final _telCtrl = TextEditingController();

  TipoVialidad? _vialidadTipo;
  final _vialidadNombreCtrl = TextEditingController();

  TipoAsentamiento? _asentTipo;
  final _asentNombreCtrl = TextEditingController();

  final _ciudadCtrl = TextEditingController();
  final _estadoCtrl = TextEditingController();
  final _cpCtrl = TextEditingController();
  final _claveElectorCtrl = TextEditingController();

  bool _savingCliente = false;
  ClienteRow? _clienteCreado;

  bool get _esEdicionDeClienteExistente => widget.clienteInicial != null;

  @override
  void initState() {
    super.initState();

    final c = widget.clienteInicial;
    if (c != null) {
      _clienteCreado = c;
      _step = 1;
      _cargarAvales();

      // ✅ si viene desde el botón "+"
      if (widget.abrirFormularioAval) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _abrirDialogAval();
        });
      }
    }
  }

  Future<void> _cargarAvales() async {
    final c = _clienteCreado ?? widget.clienteInicial;
    if (c == null) return;

    setState(() => _loadingAvales = true);

    try {
      final avales = await _svc.listarAvalesDeCliente(clienteId: c.id);

      if (!mounted) return;
      setState(() {
        _avalesBD = avales;
        _loadingAvales = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingAvales = false);
      _snack('Error cargando avales: $e', isError: true);
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apPatCtrl.dispose();
    _apMatCtrl.dispose();
    _telCtrl.dispose();
    _vialidadNombreCtrl.dispose();
    _asentNombreCtrl.dispose();
    _ciudadCtrl.dispose();
    _estadoCtrl.dispose();
    _cpCtrl.dispose();
    _claveElectorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Registro de clientes', style: t.titleLarge),
          const SizedBox(height: 16),

          _StepperHeader(step: _step, codigo: _clienteCreado?.codigo),
          const SizedBox(height: 14),

          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _step == 0 ? _buildClienteForm() : _buildAvalesStep(),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // STEP 1: CLIENTE
  // =========================
  Widget _buildClienteForm() {
    final t = Theme.of(context).textTheme;

    return SingleChildScrollView(
      key: const ValueKey('cliente'),
      child: Form(
        key: _formClienteKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: 'Datos del cliente'),
            const SizedBox(height: 10),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _field(
                  width: 360,
                  child: TextFormField(
                    controller: _nombreCtrl,
                    style: const TextStyle(color: AppTheme.text1),
                    decoration: const InputDecoration(labelText: 'Nombre(s) *'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                  ),
                ),
                _field(
                  width: 300,
                  child: TextFormField(
                    controller: _apPatCtrl,
                    style: const TextStyle(color: AppTheme.text1),
                    decoration: const InputDecoration(
                      labelText: 'Apellido paterno *',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                  ),
                ),
                _field(
                  width: 300,
                  child: TextFormField(
                    controller: _apMatCtrl,
                    style: const TextStyle(color: AppTheme.text1),
                    decoration: const InputDecoration(
                      labelText: 'Apellido materno',
                    ),
                  ),
                ),
                _field(
                  width: 240,
                  child: TextFormField(
                    controller: _telCtrl,
                    style: const TextStyle(color: AppTheme.text1),
                    decoration: const InputDecoration(labelText: 'Teléfono'),
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            _SectionTitle(title: 'Domicilio'),
            const SizedBox(height: 10),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _field(
                  width: 220,
                  child: DropdownButtonFormField<TipoVialidad>(
                    initialValue: _vialidadTipo,
                    items: TipoVialidad.values
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.name.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _vialidadTipo = v),
                    dropdownColor: AppTheme.surface,
                    decoration: const InputDecoration(
                      labelText: 'Tipo vialidad',
                    ),
                  ),
                ),
                _field(
                  width: 420,
                  child: TextFormField(
                    controller: _vialidadNombreCtrl,
                    style: const TextStyle(color: AppTheme.text1),
                    decoration: const InputDecoration(
                      labelText: 'Nombre vialidad (ej. Hidalgo 123)',
                    ),
                    validator: (_) {
                      final tipo = _vialidadTipo;
                      final nombre = _vialidadNombreCtrl.text.trim();
                      if (tipo == null && nombre.isEmpty) return null;
                      if (tipo != null && nombre.isNotEmpty) return null;
                      return 'Selecciona tipo y escribe el nombre (o deja ambos vacíos).';
                    },
                  ),
                ),
                _field(
                  width: 240,
                  child: DropdownButtonFormField<TipoAsentamiento>(
                    initialValue: _asentTipo,
                    items: TipoAsentamiento.values
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.name.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _asentTipo = v),
                    dropdownColor: AppTheme.surface,
                    decoration: const InputDecoration(
                      labelText: 'Tipo asentamiento',
                    ),
                  ),
                ),
                _field(
                  width: 420,
                  child: TextFormField(
                    controller: _asentNombreCtrl,
                    style: const TextStyle(color: AppTheme.text1),
                    decoration: const InputDecoration(
                      labelText: 'Nombre (colonia/fracc.)',
                    ),
                    validator: (_) {
                      final tipo = _asentTipo;
                      final nombre = _asentNombreCtrl.text.trim();
                      if (tipo == null && nombre.isEmpty) return null;
                      if (tipo != null && nombre.isNotEmpty) return null;
                      return 'Selecciona tipo y escribe el nombre (o deja ambos vacíos).';
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _field(
                  width: 260,
                  child: TextFormField(
                    controller: _ciudadCtrl,
                    style: const TextStyle(color: AppTheme.text1),
                    decoration: const InputDecoration(labelText: 'Ciudad'),
                  ),
                ),
                _field(
                  width: 260,
                  child: TextFormField(
                    controller: _estadoCtrl,
                    style: const TextStyle(color: AppTheme.text1),
                    decoration: const InputDecoration(labelText: 'Estado'),
                  ),
                ),
                _field(
                  width: 180,
                  child: TextFormField(
                    controller: _cpCtrl,
                    style: const TextStyle(color: AppTheme.text1),
                    decoration: const InputDecoration(labelText: 'CP'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                _field(
                  width: 300,
                  child: TextFormField(
                    controller: _claveElectorCtrl,
                    style: const TextStyle(color: AppTheme.text1),
                    decoration: const InputDecoration(
                      labelText: 'Clave elector',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: Text(
                    'El código se genera solo (iniciales + consecutivo).',
                    style: t.bodyMedium?.copyWith(color: AppTheme.text2),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _savingCliente ? null : _guardarCliente,
                    icon: _savingCliente
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(
                      _savingCliente ? 'Guardando...' : 'Guardar cliente',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // STEP 2: AVALES
  // =========================
  Widget _buildAvalesStep() {
    final t = Theme.of(context).textTheme;

    final cliente = _clienteCreado!;
    final total = _avalesBD.length + _avalesNuevos.length;

    return Column(
      key: const ValueKey('avales'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: 'Avales'),
        const SizedBox(height: 6),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${cliente.nombreCompleto}\nCódigo: ${cliente.codigo}',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: total >= 10 ? null : _abrirDialogAval,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(total >= 10 ? 'Máximo 10' : 'Agregar aval'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        Expanded(
          child: _loadingAvales
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : (total == 0)
              ? Center(
                  child: Text(
                    'Aún no agregas avales.\nDale al + cuando estés lista.',
                    textAlign: TextAlign.center,
                    style: t.bodyLarge?.copyWith(color: AppTheme.text2),
                  ),
                )
              : ListView.separated(
                  itemCount: total,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final bool esBD = i < _avalesBD.length;

                    final String nombre = esBD
                        ? _avalesBD[i].nombreCompleto
                        : _avalesNuevos[i - _avalesBD.length].nombreCorto;

                    final String? telefono = esBD
                        ? _avalesBD[i].telefono
                        : _avalesNuevos[i - _avalesBD.length].telefono;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${i + 1}. $nombre',
                                  style: t.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if ((telefono ?? '').trim().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tel: $telefono',
                                    style: t.bodyMedium?.copyWith(
                                      color: AppTheme.text2,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Solo borrar los NUEVOS (pendientes)
                          if (!esBD)
                            IconButton(
                              tooltip: 'Quitar (pendiente)',
                              onPressed: () => setState(() {
                                _avalesNuevos.removeAt(i - _avalesBD.length);
                              }),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _esEdicionDeClienteExistente
                    ? () {
                        // Si vienes de clientes, "volver" solo cierra el paso de avales
                        // (tú decides si quieres volver al step 0 o quedarte)
                        setState(() => _step = 1);
                      }
                    : () => setState(() => _step = 0),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Volver'),
              ),
            ),
            const Spacer(),

            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _savingAvales
                    ? null
                    : (_avalesNuevos.isEmpty ? null : _guardarAvales),
                icon: _savingAvales
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(_savingAvales ? 'Guardando...' : 'Guardar avales'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _guardarCliente() async {
    final ok = _formClienteKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _savingCliente = true);

    try {
      final input = ClienteInput(
        nombre: _nombreCtrl.text,
        apellidoPaterno: _apPatCtrl.text,
        apellidoMaterno: _apMatCtrl.text.trim().isEmpty
            ? null
            : _apMatCtrl.text,
        telefono: _telCtrl.text.trim().isEmpty ? null : _telCtrl.text,
        vialidadTipo: _vialidadTipo,
        vialidadNombre: _vialidadNombreCtrl.text.trim().isEmpty
            ? null
            : _vialidadNombreCtrl.text,
        asentamientoTipo: _asentTipo,
        asentamientoNombre: _asentNombreCtrl.text.trim().isEmpty
            ? null
            : _asentNombreCtrl.text,
        ciudad: _ciudadCtrl.text.trim().isEmpty ? null : _ciudadCtrl.text,
        estado: _estadoCtrl.text.trim().isEmpty ? null : _estadoCtrl.text,
        cp: _cpCtrl.text.trim().isEmpty ? null : _cpCtrl.text,
        claveElector: _claveElectorCtrl.text.trim().isEmpty
            ? null
            : _claveElectorCtrl.text,
      );

      final cliente = await _svc.crearClienteConCodigo(input);

      setState(() {
        _clienteCreado = cliente;
        _step = 1;
      });

      await _cargarAvales();

      if (!mounted) return;
      _snack('Cliente guardado: ${cliente.codigo}');
    } catch (e) {
      _snack('Error guardando cliente: $e', isError: true);
    } finally {
      if (mounted) setState(() => _savingCliente = false);
    }
  }

  Future<void> _guardarAvales() async {
    final cliente = _clienteCreado;
    if (cliente == null) return;
    if (_avalesNuevos.isEmpty) return;

    setState(() => _savingAvales = true);

    try {
      await _svc.insertarAvales(clienteId: cliente.id, avales: _avalesNuevos);

      if (!mounted) return;
      _snack('Avales guardados (${_avalesNuevos.length}).');

      // Limpia pendientes y recarga avales reales
      setState(() => _avalesNuevos.clear());
      await _cargarAvales();
    } catch (e) {
      _snack('Error guardando avales: $e', isError: true);
    } finally {
      if (mounted) setState(() => _savingAvales = false);
    }
  }

  Future<void> _abrirDialogAval() async {
    final total = _avalesBD.length + _avalesNuevos.length;
    if (total >= 10) {
      _snack('Ya llegaste a 10 avales.', isError: true);
      return;
    }

    final res = await showDialog<AvalInput>(
      context: context,
      builder: (_) => const _DialogAval(),
    );

    if (res == null) return;

    final total2 = _avalesBD.length + _avalesNuevos.length;
    if (total2 >= 10) {
      _snack('Ya llegaste a 10 avales.', isError: true);
      return;
    }

    setState(() => _avalesNuevos.add(res));
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : null,
      ),
    );
  }

  Widget _field({required double width, required Widget child}) {
    return SizedBox(width: width, child: child);
  }
}

class _StepperHeader extends StatelessWidget {
  final int step;
  final String? codigo;

  const _StepperHeader({required this.step, required this.codigo});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        _chip(step == 0, '1) Cliente'),
        const SizedBox(width: 8),
        _chip(step == 1, '2) Avales'),
        const Spacer(),
        if (codigo != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              'Código: $codigo',
              style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
      ],
    );
  }

  Widget _chip(bool active, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? AppTheme.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? AppTheme.accent : AppTheme.border),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: active ? AppTheme.text1 : AppTheme.text2,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Text(
      title,
      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
    );
  }
}

class _DialogAval extends StatefulWidget {
  const _DialogAval();

  @override
  State<_DialogAval> createState() => _DialogAvalState();
}

class _DialogAvalState extends State<_DialogAval> {
  final _formKey = GlobalKey<FormState>();

  final _nombreCtrl = TextEditingController();
  final _apPatCtrl = TextEditingController();
  final _apMatCtrl = TextEditingController();
  final _telCtrl = TextEditingController();

  TipoVialidad? _vialidadTipo;
  final _vialidadNombreCtrl = TextEditingController();

  TipoAsentamiento? _asentTipo;
  final _asentNombreCtrl = TextEditingController();

  final _ciudadCtrl = TextEditingController();
  final _estadoCtrl = TextEditingController();
  final _cpCtrl = TextEditingController();
  final _claveElectorCtrl = TextEditingController();

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apPatCtrl.dispose();
    _apMatCtrl.dispose();
    _telCtrl.dispose();
    _vialidadNombreCtrl.dispose();
    _asentNombreCtrl.dispose();
    _ciudadCtrl.dispose();
    _estadoCtrl.dispose();
    _cpCtrl.dispose();
    _claveElectorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text('Agregar aval', style: t.titleLarge),
      content: SizedBox(
        width: 760,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 320,
                  child: TextFormField(
                    controller: _nombreCtrl,
                    style: const TextStyle(color: AppTheme.text1),
                    decoration: const InputDecoration(labelText: 'Nombre(s) *'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: TextFormField(
                    controller: _apPatCtrl,
                    style: const TextStyle(color: AppTheme.text1),
                    decoration: const InputDecoration(
                      labelText: 'Apellido paterno *',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: TextFormField(
                    controller: _apMatCtrl,
                    style: const TextStyle(color: AppTheme.text1),
                    decoration: const InputDecoration(
                      labelText: 'Apellido materno',
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: _telCtrl,
                    style: const TextStyle(color: AppTheme.text1),
                    decoration: const InputDecoration(labelText: 'Teléfono'),
                    keyboardType: TextInputType.phone,
                  ),
                ),

                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<TipoVialidad>(
                    initialValue: _vialidadTipo,
                    items: TipoVialidad.values
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.name.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _vialidadTipo = v),
                    dropdownColor: AppTheme.surface,
                    decoration: const InputDecoration(
                      labelText: 'Tipo vialidad',
                    ),
                  ),
                ),
                SizedBox(
                  width: 420,
                  child: TextFormField(
                    controller: _vialidadNombreCtrl,
                    style: const TextStyle(color: AppTheme.text1),
                    decoration: const InputDecoration(
                      labelText: 'Nombre vialidad',
                    ),
                    validator: (_) {
                      final tipo = _vialidadTipo;
                      final nombre = _vialidadNombreCtrl.text.trim();
                      if (tipo == null && nombre.isEmpty) return null;
                      if (tipo != null && nombre.isNotEmpty) return null;
                      return 'Tipo y nombre juntos (o ambos vacíos).';
                    },
                  ),
                ),

                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<TipoAsentamiento>(
                    initialValue: _asentTipo,
                    items: TipoAsentamiento.values
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.name.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _asentTipo = v),
                    dropdownColor: AppTheme.surface,
                    decoration: const InputDecoration(
                      labelText: 'Tipo asentamiento',
                    ),
                  ),
                ),
                SizedBox(
                  width: 420,
                  child: TextFormField(
                    controller: _asentNombreCtrl,
                    style: const TextStyle(color: AppTheme.text1),
                    decoration: const InputDecoration(
                      labelText: 'Nombre (colonia/fracc.)',
                    ),
                    validator: (_) {
                      final tipo = _asentTipo;
                      final nombre = _asentNombreCtrl.text.trim();
                      if (tipo == null && nombre.isEmpty) return null;
                      if (tipo != null && nombre.isNotEmpty) return null;
                      return 'Tipo y nombre juntos (o ambos vacíos).';
                    },
                  ),
                ),

                SizedBox(
                  width: 240,
                  child: TextFormField(
                    controller: _ciudadCtrl,
                    style: const TextStyle(color: AppTheme.text1),
                    decoration: const InputDecoration(labelText: 'Ciudad'),
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: TextFormField(
                    controller: _estadoCtrl,
                    style: const TextStyle(color: AppTheme.text1),
                    decoration: const InputDecoration(labelText: 'Estado'),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: TextFormField(
                    controller: _cpCtrl,
                    style: const TextStyle(color: AppTheme.text1),
                    decoration: const InputDecoration(labelText: 'CP'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: TextFormField(
                    controller: _claveElectorCtrl,
                    style: const TextStyle(color: AppTheme.text1),
                    decoration: const InputDecoration(
                      labelText: 'Clave elector',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            final ok = _formKey.currentState?.validate() ?? false;
            if (!ok) return;

            final aval = AvalInput(
              nombre: _nombreCtrl.text,
              apellidoPaterno: _apPatCtrl.text,
              apellidoMaterno: _apMatCtrl.text.trim().isEmpty
                  ? null
                  : _apMatCtrl.text,
              telefono: _telCtrl.text.trim().isEmpty ? null : _telCtrl.text,
              vialidadTipo: _vialidadTipo,
              vialidadNombre: _vialidadNombreCtrl.text.trim().isEmpty
                  ? null
                  : _vialidadNombreCtrl.text,
              asentamientoTipo: _asentTipo,
              asentamientoNombre: _asentNombreCtrl.text.trim().isEmpty
                  ? null
                  : _asentNombreCtrl.text,
              ciudad: _ciudadCtrl.text.trim().isEmpty ? null : _ciudadCtrl.text,
              estado: _estadoCtrl.text.trim().isEmpty ? null : _estadoCtrl.text,
              cp: _cpCtrl.text.trim().isEmpty ? null : _cpCtrl.text,
              claveElector: _claveElectorCtrl.text.trim().isEmpty
                  ? null
                  : _claveElectorCtrl.text,
            );

            Navigator.pop(context, aval);
          },
          icon: const Icon(Icons.check_rounded),
          label: const Text('Agregar'),
        ),
      ],
    );
  }
}
