import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:withaprest/models/registro_model.dart';
import 'package:withaprest/services/registro_service.dart';
import 'package:withaprest/theme/iniciotema.dart';

typedef OnAvales = void Function(ClienteRow c, {bool nuevo});

class ClientesPage extends StatefulWidget {
  final VoidCallback onRegistrar;

  // 💰
  final ValueChanged<ClienteRow> onIrPrestamos;

  // 👤
  final OnAvales onAvales;

  const ClientesPage({
    super.key,
    required this.onRegistrar,
    required this.onIrPrestamos,
    required this.onAvales,
  });

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  final _svc = RegistroService();

  final _qCtrl = TextEditingController();
  final _qFocus = FocusNode();
  Timer? _debounce;

  bool _loading = true;
  String? _error;

  bool _searching = false;
  List<ClienteRow> _items = [];

  int _offset = 0;
  static const int _pageSize = 50; // ✅ 50
  bool _loadingMore = false;
  bool _hasMore = true;

  bool _asc = true; // A→Z

  @override
  void initState() {
    super.initState();
    _qCtrl.addListener(() {
      if (mounted) setState(() {}); // para refrescar suffixIcon
    });
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
      _items = [];
      _offset = 0;
      _hasMore = true;
    });

    try {
      final res = await _svc.listarClientesConAvalesCount(
        limit: _pageSize,
        offset: 0,
        asc: _asc,
      );

      if (!mounted) return;

      setState(() {
        _items = res;
        _loading = false;
        _hasMore = res.length == _pageSize;
        _offset = res.length;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Error cargando clientes: $e';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    if (_qCtrl.text.trim().isNotEmpty) return; // si estás buscando, no pagines

    setState(() => _loadingMore = true);

    try {
      final res = await _svc.listarClientesConAvalesCount(
        limit: _pageSize,
        offset: _offset,
        asc: _asc,
      );

      if (!mounted) return;

      setState(() {
        _items.addAll(res);
        _offset += res.length;
        _hasMore = res.length == _pageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _onQueryChanged(String v) {
    _debounce?.cancel();
    final q = v.trim();

    if (q.isEmpty) {
      setState(() {
        _searching = false;
        _error = null;
      });
      _loadInitial();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) return;

      setState(() {
        _searching = true;
        _error = null;
      });

      try {
        final res = await _svc.buscarClientesConAvalesCount(
          q: q,
          asc: _asc,
          limit: 50,
        );

        if (!mounted) return;

        setState(() {
          _items = res;
          _searching = false;
          _hasMore = false; // búsqueda no pagina
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _items = [];
          _searching = false;
          _error = 'Error buscando: $e';
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _qCtrl.dispose();
    _qFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header interno
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface2,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.border),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Selecciona un cliente',
                      style: t.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),

                  // Orden A-Z / Z-A
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        _OrderChip(
                          selected: _asc,
                          text: 'A→Z',
                          onTap: () {
                            setState(() => _asc = true);
                            _loadInitial();
                          },
                        ),
                        _OrderChip(
                          selected: !_asc,
                          text: 'Z→A',
                          onTap: () {
                            setState(() => _asc = false);
                            _loadInitial();
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: 'Recargar',
                    onPressed: _loadInitial,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: AppTheme.text2,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Buscador interno
            TextField(
              controller: _qCtrl,
              focusNode: _qFocus,
              inputFormatters: [UpperCaseTextFormatter()],
              style: const TextStyle(color: AppTheme.text1),
              decoration: InputDecoration(
                labelText: 'Buscar aquí (código o nombre)',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                suffixIcon: _qCtrl.text.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar',
                        onPressed: () {
                          _debounce?.cancel();
                          _qCtrl.clear(); // el listener hará setState()
                          FocusScope.of(context).requestFocus(_qFocus);
                          _loadInitial();
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
              onChanged: _onQueryChanged,
            ),

            const SizedBox(height: 12),

            Expanded(
              child: _loading
                  ? const _LoadingBox()
                  : _error != null
                  ? _ErrorBox(msg: _error!, onRetry: _loadInitial)
                  : _searching
                  ? const _LoadingBoxBuscando()
                  : _items.isEmpty
                  ? const _EmptyBox()
                  : NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n.metrics.pixels >=
                            n.metrics.maxScrollExtent - 240) {
                          _loadMore();
                        }
                        return false;
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 84),
                        itemCount: _items.length + (_loadingMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          if (_loadingMore && i == _items.length) {
                            return const _LoadingMoreTile();
                          }

                          final c = _items[i];
                          final canAddAval = c.avalesCount < 10;

                          return _ClienteTile(
                            cliente: c,
                            onPrestamo: () => widget.onIrPrestamos(c),

                            // ✅ tocar tarjeta => ver avales (NO formulario)
                            onTapTile: () => widget.onAvales(c, nuevo: false),

                            // ✅ botón + => abrir formulario directo
                            onNuevoAval: canAddAval
                                ? () => widget.onAvales(c, nuevo: true)
                                : null,
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),

        // FAB Registrar
        Positioned(
          right: 18,
          bottom: 18,
          child: FloatingActionButton.extended(
            backgroundColor: AppTheme.accent,
            foregroundColor: AppTheme.text1,
            onPressed: widget.onRegistrar,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Registrar'),
          ),
        ),
      ],
    );
  }
}

class _ClienteTile extends StatelessWidget {
  final ClienteRow cliente;
  final VoidCallback onPrestamo;

  final VoidCallback onTapTile; // ✅ tap en tarjeta
  final VoidCallback? onNuevoAval; // ✅ botón +

  const _ClienteTile({
    required this.cliente,
    required this.onPrestamo,
    required this.onTapTile,
    required this.onNuevoAval,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTapTile, // 👈 CLICK EN LA PERSONA/TARJETA
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Icon(Icons.person_rounded, color: AppTheme.text1),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cliente.nombreCompleto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.text1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Código: ${cliente.codigo}  •  Avales: ${cliente.avalesCount}/10',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyMedium?.copyWith(color: AppTheme.text2),
                    ),
                  ],
                ),
              ),

              if (onNuevoAval != null) ...[
                _IconBtn(
                  tooltip: 'Nuevo aval',
                  icon: Icons.person_add_alt_1_rounded,
                  onTap: onNuevoAval!, // 👈 SOLO ESTE abre formulario
                ),
                const SizedBox(width: 8),
              ],

              _IconBtn(
                tooltip: 'Préstamos',
                icon: Icons.attach_money_rounded,
                onTap: onPrestamo,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  const _IconBtn({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;

    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: disabled ? 0.45 : 1,
        child: Material(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Icon(icon, color: AppTheme.text1, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox();

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
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(height: 12),
            Text('Cargando clientes...', style: t.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _LoadingMoreTile extends StatelessWidget {
  const _LoadingMoreTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(18),
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox();

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
            'No hay clientes',
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Usa la búsqueda o registra uno nuevo con el botón de abajo.',
            style: t.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;

  const _ErrorBox({required this.msg, required this.onRetry});

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
          Text(msg, style: t.bodyMedium?.copyWith(color: Colors.redAccent)),
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

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class _OrderChip extends StatelessWidget {
  final bool selected;
  final String text;
  final VoidCallback onTap;

  const _OrderChip({
    required this.selected,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.surface2 : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppTheme.accent : Colors.transparent,
              width: 1,
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: selected ? AppTheme.text1 : AppTheme.text2,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingBoxBuscando extends StatelessWidget {
  const _LoadingBoxBuscando();

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
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(height: 12),
            Text('Buscando...', style: t.bodyMedium),
          ],
        ),
      ),
    );
  }
}
