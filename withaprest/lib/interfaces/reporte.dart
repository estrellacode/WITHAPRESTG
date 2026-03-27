import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:withaprest/models/reporte_model.dart';
import 'package:withaprest/services/reporte_services.dart';
import 'package:withaprest/theme/iniciotema.dart';

class ReporteCobranzaPage extends StatefulWidget {
  const ReporteCobranzaPage({super.key});

  @override
  State<ReporteCobranzaPage> createState() => _ReporteCobranzaPageState();
}

class _ReporteCobranzaPageState extends State<ReporteCobranzaPage> {
  final _svc = ReporteControlCobranzaService();

  DateTime _fecha = DateTime.now();
  bool _loading = true;
  String? _error;

  List<ReporteControlCobranzaRow> _items = [];
  final Set<String> _guardando = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final data = await _svc.listarPorFecha(_fecha);

      if (!mounted) return;
      setState(() {
        _items = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el reporte: $e';
        _loading = false;
      });
    }
  }

  Future<void> _pickFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      builder: (context, child) => Theme(data: AppTheme.theme(), child: child!),
    );

    if (picked == null) return;

    setState(() => _fecha = picked);
    await _load();
  }

  Future<void> _cambiarPagada(int index, bool value) async {
    final item = _items[index];

    setState(() {
      _guardando.add(item.cuotaId);
      _items[index] = item.copyWith(pagada: value);
    });

    try {
      await _svc.actualizarPagada(cuotaId: item.cuotaId, pagada: value);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items[index] = item;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo actualizar: $e')));
    } finally {
      if (!mounted) return;
      setState(() {
        _guardando.remove(item.cuotaId);
      });
    }
  }

  String _frecuenciaTexto(FrecuenciaPrestamo f) {
    switch (f) {
      case FrecuenciaPrestamo.semanal:
        return 'Semanal';
      case FrecuenciaPrestamo.quincenal:
        return 'Quincenal';
      case FrecuenciaPrestamo.mensual:
        return 'Mensual';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final fechaTxt = DateFormat('dd/MM/yyyy').format(_fecha);

    if (_loading) return const _LoadingReporteCobranza();
    if (_error != null) {
      return _ErrorReporteCobranza(mensaje: _error!, onRetry: _load);
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _pickFecha,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surface2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Fecha de cobro', style: t.bodyMedium),
                            const SizedBox(height: 2),
                            Text(fechaTxt, style: t.bodyLarge),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Actualizar'),
            ),
          ],
        ),

        const SizedBox(height: 16),

        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Registros del día: ${_items.length}',
            style: t.bodyMedium,
          ),
        ),

        const SizedBox(height: 10),

        Expanded(
          child: _items.isEmpty
              ? const _EmptyReporteCobranza()
              : ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final item = _items[i];
                    final saving = _guardando.contains(item.cuotaId);

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface2,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              item.codigo,
                              style: t.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.text1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.nombreCliente,
                                  style: t.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.text1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_frecuenciaTexto(item.frecuencia)} • Cuota ${item.numCuota}',
                                  style: t.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 180,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('Pagó', style: t.bodyLarge),
                                const SizedBox(width: 10),
                                if (saving)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                else
                                  Switch(
                                    value: item.pagada,
                                    onChanged: (v) => _cambiarPagada(i, v),
                                  ),
                                const SizedBox(width: 6),
                                Text(
                                  item.pagada ? 'Sí' : 'No',
                                  style: t.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: item.pagada
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _LoadingReporteCobranza extends StatelessWidget {
  const _LoadingReporteCobranza();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(height: 12),
            Text('Cargando control de cobranza...'),
          ],
        ),
      ),
    );
  }
}

class _ErrorReporteCobranza extends StatelessWidget {
  final String mensaje;
  final VoidCallback onRetry;

  const _ErrorReporteCobranza({required this.mensaje, required this.onRetry});

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
          Text(
            'Ups…',
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(mensaje, style: t.bodyMedium?.copyWith(color: Colors.redAccent)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

class _EmptyReporteCobranza extends StatelessWidget {
  const _EmptyReporteCobranza();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.event_busy_outlined,
                size: 34,
                color: AppTheme.text2,
              ),
              const SizedBox(height: 12),
              Text('No hay cobros para esta fecha', style: t.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Selecciona otro día en el calendario.',
                style: t.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
