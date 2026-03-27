import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:withaprest/models/cobranza_model.dart';
import 'package:withaprest/services/cobranza_services.dart';
import 'package:withaprest/theme/iniciotema.dart';

class ListaCobranzaPage extends StatefulWidget {
  const ListaCobranzaPage({super.key});

  @override
  State<ListaCobranzaPage> createState() => _ListaCobranzaPageState();
}

class _ListaCobranzaPageState extends State<ListaCobranzaPage> {
  final _svc = ListaCobranzaService();
  final _searchCtrl = TextEditingController();

  Timer? _debounce;

  bool _loading = true;
  bool _soloAtrasados = false;
  String? _error;

  List<ListaCobranzaRow> _items = [];

  final _money = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final data = await _svc.listar(
        query: _searchCtrl.text,
        soloAtrasados: _soloAtrasados,
      );

      if (!mounted) return;
      setState(() {
        _items = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar la lista de cobranza: $e';
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), _load);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    if (_loading) return const _LoadingBoxCobranza();

    if (_error != null) {
      return _ErrorBoxCobranza(mensaje: _error!, onRetry: _load);
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  labelText: 'Buscar por código o nombre',
                  hintText: 'Ej. ANA001 o Juan Pérez',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar',
                          onPressed: () {
                            _searchCtrl.clear();
                            _load();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilterChip(
              selected: _soloAtrasados,
              label: const Text('Solo atrasados'),
              onSelected: (v) {
                setState(() => _soloAtrasados = v);
                _load();
              },
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
          child: Text('Registros: ${_items.length}', style: t.bodyMedium),
        ),

        const SizedBox(height: 10),

        Expanded(
          child: _items.isEmpty
              ? const _EmptyCobranzaBox()
              : ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final item = _items[i];
                    return _CobranzaCard(item: item, money: _money);
                  },
                ),
        ),
      ],
    );
  }
}

class _CobranzaCard extends StatelessWidget {
  final ListaCobranzaRow item;
  final NumberFormat money;

  const _CobranzaCard({required this.item, required this.money});

  Color _badgeColor() {
    if (item.diasAtrasados > 0) return Colors.redAccent;
    return Colors.greenAccent;
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
    final venceTxt = item.venceActual == null
        ? 'Sin fecha'
        : DateFormat('dd/MM/yyyy').format(item.venceActual!);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text(
                      item.codigo,
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.text1,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _badgeColor().withOpacity(.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _badgeColor().withOpacity(.45),
                        ),
                      ),
                      child: Text(
                        item.diasAtrasados > 0
                            ? '${item.diasAtrasados} día(s) atrasado(s)'
                            : 'Al corriente',
                        style: t.bodyMedium?.copyWith(
                          color: _badgeColor(),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            item.nombreCliente,
            style: t.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.text1,
            ),
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MiniDato(
                icon: Icons.payments_outlined,
                label: 'Cantidad a abonar',
                value: money.format(item.aAbonar),
              ),
              _MiniDato(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Saldo cuota actual',
                value: money.format(item.saldoCuotaActual),
              ),
              _MiniDato(
                icon: Icons.calendar_view_week_outlined,
                label: 'Semana / cuota',
                value: '${item.cuotaActual}',
              ),
              _MiniDato(
                icon: Icons.event_outlined,
                label: 'Vence',
                value: venceTxt,
              ),
              _MiniDato(
                icon: Icons.warning_amber_rounded,
                label: 'Cuotas atrasadas',
                value: '${item.cuotasAtrasadas}',
              ),
              _MiniDato(
                icon: Icons.repeat_outlined,
                label: 'Frecuencia',
                value: _frecuenciaTexto(item.frecuencia),
              ),
            ],
          ),

          if ((item.domicilio ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, color: AppTheme.text2),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.domicilio!,
                      style: t.bodyMedium?.copyWith(color: AppTheme.text2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniDato extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniDato({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppTheme.text2),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: t.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.text1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBoxCobranza extends StatelessWidget {
  const _LoadingBoxCobranza();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(height: 12),
              Text('Cargando lista de cobranza...'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBoxCobranza extends StatelessWidget {
  final String mensaje;
  final VoidCallback onRetry;

  const _ErrorBoxCobranza({required this.mensaje, required this.onRetry});

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

class _EmptyCobranzaBox extends StatelessWidget {
  const _EmptyCobranzaBox();

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
              const Icon(Icons.inbox_outlined, size: 34, color: AppTheme.text2),
              const SizedBox(height: 12),
              Text('No hay registros de cobranza', style: t.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Prueba con otra búsqueda o quita el filtro de atrasados.',
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
