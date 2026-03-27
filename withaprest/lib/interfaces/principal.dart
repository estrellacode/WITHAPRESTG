import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:withaprest/interfaces/clientes.dart';
import 'package:withaprest/interfaces/cobranzas.dart';
import 'package:withaprest/interfaces/prestamo.dart';
import 'package:withaprest/interfaces/registro.dart';
import 'package:withaprest/interfaces/reporte.dart';
import 'package:withaprest/models/perfil_model.dart';
import 'package:withaprest/models/prestamo_model.dart';
import 'package:withaprest/models/registro_model.dart';
import 'package:withaprest/services/perfil_service.dart';
import 'package:withaprest/services/prestamo_services.dart';
import 'package:withaprest/services/registro_service.dart';
import 'package:withaprest/theme/iniciotema.dart';

// Tip: si ya tienes auth, aquí luego jalas el perfil real desde Supabase
class Principal extends StatefulWidget {
  const Principal({super.key});

  @override
  State<Principal> createState() => _PrincipalState();
}

enum MenuKey {
  clientes,
  registro,
  prestamo,
  listaCobranza,
  reporteCobranza,
  extra,
  configuracion,
}

enum PrestamoMode { nuevo, renovacion }

class _PrincipalState extends State<Principal> {
  bool _railExpanded = true;

  MenuKey _menu = MenuKey.clientes;

  PrestamoMode _prestamoMode = PrestamoMode.nuevo;

  final _perfilService = PerfilService();

  ProfileModel? _perfil;
  bool _perfilLoading = true;
  String? _perfilError;
  bool _registroNuevoAval = false;
  bool _abrirFormularioAval = false;

  //busqueda
  final _registroSvc = RegistroService();

  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _searching = false;
  List<ClienteRow> _searchResults = [];

  final FocusNode _searchFocus = FocusNode();

  ClienteRow? _clienteParaRegistro;

  final LayerLink _searchLink = LayerLink();
  OverlayEntry? _searchOverlay;

  static const double _searchWidth = 520;

  bool get showTopSearch =>
      _menu != MenuKey.registro && _menu != MenuKey.clientes;

  //PRESTAMO
  ClienteRow? _clienteSeleccionadoParaPrestamo;
  String _seccion = 'clientes'; // o enum, como lo tengas
  String _subPrestamo = 'nuevo'; // 'nuevo' | 'renovacion'
  ClienteRow? _clientePrestamo;
  PrestamoRow? _prestamoActivoCliente;
  bool _resolviendoPrestamo = false;
  String? _prestamoError;
  bool _tuvoPrestamosAntes = false; //

  @override
  void initState() {
    super.initState();
    _cargarPerfil();

    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus) {
        _removeSearchOverlay();
      }
    });
  }

  // Cargar perfil del usuario que ingreso
  Future<void> _cargarPerfil() async {
    setState(() {
      _perfilLoading = true;
      _perfilError = null;
    });

    try {
      final sb = Supabase.instance.client;
      final user = sb.auth.currentUser;

      if (user == null) {
        setState(() {
          _perfil = null;
          _perfilLoading = false;
          _perfilError = 'No hay sesión activa.';
        });
        return;
      }

      final perfil = await _perfilService.obtenerPerfilActual();

      if (perfil == null) {
        setState(() {
          _perfil = ProfileModel(
            id: user.id,
            rol: 'usuario',
            nombre: user.email ?? 'Usuario',
          );
          _perfilLoading = false;
        });
        return;
      }

      setState(() {
        _perfil = perfil;
        _perfilLoading = false;
      });
    } catch (e) {
      setState(() {
        _perfilLoading = false;
        _perfilError = 'Error cargando perfil: $e';
      });
    }
  }

  //Validación
  Future<void> _irAPrestamoAuto(ClienteRow c) async {
    setState(() {
      _clientePrestamo = c;
      _menu = MenuKey.prestamo;
      _prestamoActivoCliente = null;
      _resolviendoPrestamo = true;
      _prestamoError = null;
    });

    try {
      final svc = PrestamoService();
      final activo = await svc.getPrestamoActivoCliente(c.id);

      if (!mounted) return;

      setState(() {
        _prestamoActivoCliente = activo;
        _prestamoMode = (activo != null)
            ? PrestamoMode.renovacion
            : PrestamoMode.nuevo;
        _resolviendoPrestamo = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _prestamoError = 'No se pudo validar el préstamo del cliente: $e';
        _resolviendoPrestamo = false;
        _prestamoMode = PrestamoMode.nuevo;
      });
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();

    final q = v.trim();

    if (q.isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      _removeSearchOverlay();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 250), () async {
      setState(() => _searching = true);
      _showSearchOverlay();
      _refreshSearchOverlay(); // 👈

      try {
        final res = await _registroSvc.buscarClientes(q);

        if (!mounted) return;
        setState(() {
          _searchResults = res;
          _searching = false;
        });

        // 👇 Esto es lo que te faltaba
        if (_searchResults.isEmpty) {
          _removeSearchOverlay(); // opcional: esconder si no hay
        } else {
          _showSearchOverlay(); // por si se cerró
          _refreshSearchOverlay();
        }
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _searchResults = [];
          _searching = false;
        });
        _removeSearchOverlay();
      }
    });
  }

  void _selectClienteFromSearch(ClienteRow c) {
    setState(() {
      _clienteParaRegistro = c;
      _menu = MenuKey.registro; // cambia a Registro
      _searchResults = [];
      _searchCtrl.clear();
      _searchFocus.unfocus();
    });
  }

  void _irAPrestamoNuevo(ClienteRow c) {
    setState(() {
      _clienteSeleccionadoParaPrestamo = c;
      _seccion = 'prestamo';
      _subPrestamo = 'nuevo';
    });
  }

  void _removeSearchOverlay() {
    _searchOverlay?.remove();
    _searchOverlay = null;
  }

  void _showSearchOverlay() {
    if (_searchOverlay != null) return;

    _searchOverlay = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: Stack(
            children: [
              // Click fuera = cerrar
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  _searchFocus.unfocus();
                  setState(() {
                    _searchResults = [];
                    _searching = false;
                  });
                  _removeSearchOverlay();
                },
              ),

              // Panel anclado al TextField
              CompositedTransformFollower(
                link: _searchLink,
                showWhenUnlinked: false,
                offset: const Offset(0, 64), // debajo del input
                child: Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    height: 54,
                    width: _searchWidth,
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 260),
                      decoration: BoxDecoration(
                        color: AppTheme.surface2,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 14,
                            offset: Offset(0, 8),
                            color: Color(0x22000000),
                          ),
                        ],
                      ),
                      child: _searching
                          ? const SizedBox(
                              height: 54,
                              child: Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: _searchResults.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final c = _searchResults[i];
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    c.nombreCompleto,
                                    style: const TextStyle(
                                      color: AppTheme.text1,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Código: ${c.codigo}',
                                    style: const TextStyle(
                                      color: AppTheme.text2,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                  ),
                                  onTap: () => _selectClienteFromSearch(c),
                                );
                              },
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    Overlay.of(context).insert(_searchOverlay!);
  }

  void _refreshSearchOverlay() {
    _searchOverlay?.markNeedsBuild();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeSearchOverlay();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.25,
            colors: [
              Color(0xFF232A3D), // antes 1A1E2A
              AppTheme.bg,
            ],
          ),
        ),

        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // ======================
                // MENU DESPLEGABLE
                // ======================
                Container(
                  width: _railExpanded ? 290 : 110,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 18,
                        offset: Offset(0, 10),
                        color: Color(0x22000000),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),

                      // ===== USER HEADER =====
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: IntrinsicHeight(
                          child: _railExpanded
                              ? _HeaderExpandido(
                                  nombre: _perfil?.nombreSeguro ?? 'Usuario',
                                  rol: (_perfil?.rol ?? 'usuario')
                                      .toUpperCase(),
                                  loading: _perfilLoading,
                                  error: _perfilError,
                                  onRefresh: _cargarPerfil,
                                  onToggle: () => setState(
                                    () => _railExpanded = !_railExpanded,
                                  ),
                                )
                              : _HeaderColapsado(
                                  onToggle: () => setState(
                                    () => _railExpanded = !_railExpanded,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 10),
                      const _DividerSoft(),

                      // ===== MENU LIST =====
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: ListView(
                            children: [
                              _MenuTile(
                                expanded: _railExpanded,
                                selected: _menu == MenuKey.clientes,
                                icon: Icons.app_registration_outlined,
                                label: 'Clientes',
                                onTap: () =>
                                    setState(() => _menu = MenuKey.clientes),
                              ),
                              const SizedBox(height: 6),

                              // Prestamo (con subopciones)
                              /*   _MenuTile(
                                expanded: _railExpanded,
                                selected: _menu == MenuKey.prestamo,
                                icon: Icons.request_quote_outlined,
                                label: 'Préstamo',
                                onTap: () =>
                                    setState(() => _menu = MenuKey.prestamo),
                                trailing: _railExpanded
                                    ? const Icon(
                                        Icons.chevron_right_rounded,
                                        color: AppTheme.text2,
                                      )
                                    : null,
                              ),

                              if (_railExpanded &&
                                  _menu == MenuKey.prestamo) ...[
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.only(left: 46),
                                  child: Column(
                                    children: [
                                      _SubTile(
                                        selected:
                                            _prestamoMode == PrestamoMode.nuevo,
                                        label: 'Nuevo',
                                        onTap: () => setState(() {
                                          _menu = MenuKey.prestamo;
                                          _prestamoMode = PrestamoMode.nuevo;
                                        }),
                                      ),
                                      const SizedBox(height: 6),
                                      _SubTile(
                                        selected:
                                            _prestamoMode ==
                                            PrestamoMode.renovacion,
                                        label: 'Renovación',
                                        onTap: () => setState(() {
                                          _menu = MenuKey.prestamo;
                                          _prestamoMode =
                                              PrestamoMode.renovacion;
                                        }),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                             _MenuTile(
*/
                              const SizedBox(height: 6),
                              _MenuTile(
                                expanded: _railExpanded,
                                selected: _menu == MenuKey.listaCobranza,
                                icon: Icons.payments_outlined,
                                label: 'Lista de cobranza',
                                onTap: () => setState(
                                  () => _menu = MenuKey.listaCobranza,
                                ),
                              ),
                              const SizedBox(height: 6),

                              _MenuTile(
                                expanded: _railExpanded,
                                selected: _menu == MenuKey.reporteCobranza,
                                icon: Icons.bar_chart_outlined,
                                label: 'Reporte de cobranza',
                                onTap: () => setState(
                                  () => _menu = MenuKey.reporteCobranza,
                                ),
                              ),
                              const SizedBox(height: 6),

                              _MenuTile(
                                expanded: _railExpanded,
                                selected: _menu == MenuKey.extra,
                                icon: Icons.auto_awesome_outlined,
                                label: 'Extra',
                                onTap: () =>
                                    setState(() => _menu = MenuKey.extra),
                              ),
                              const SizedBox(height: 6),

                              _MenuTile(
                                expanded: _railExpanded,
                                selected: _menu == MenuKey.configuracion,
                                icon: Icons.settings_outlined,
                                label: 'Configuración',
                                onTap: () => setState(
                                  () => _menu = MenuKey.configuracion,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const _DividerSoft(),

                      // Footer (opcional: cerrar sesión)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                        child: _railExpanded
                            ? SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.text1,
                                    side: const BorderSide(
                                      color: AppTheme.border,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: () async {
                                    await Supabase.instance.client.auth
                                        .signOut();
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Sesión cerrada'),
                                      ),
                                    );
                                  },

                                  icon: const Icon(Icons.logout_rounded),
                                  label: const Text('Cerrar sesión'),
                                ),
                              )
                            : IconButton(
                                tooltip: 'Cerrar sesión',
                                onPressed: () async {
                                  await Supabase.instance.client.auth.signOut();
                                  // ✅ No navegues. AuthGate detecta session == null y te manda a InicioSesion
                                },

                                icon: const Icon(
                                  Icons.logout_rounded,
                                  color: AppTheme.text2,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 14),

                // ======================
                // AREA DE CONTENIDO
                // ======================
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1600),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 18,
                            offset: Offset(0, 10),
                            color: Color(0x22000000),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Top content bar (título + búsqueda) con más aire
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(_title(), style: t.titleLarge),
                                ),

                                const SizedBox(
                                  width: 18,
                                ), // 👈 separa título vs buscador

                                if (showTopSearch) ...[
                                  const SizedBox(width: 18),
                                  SizedBox(
                                    width: _searchWidth,
                                    child: CompositedTransformTarget(
                                      link: _searchLink,
                                      child: TextField(
                                        controller: _searchCtrl,
                                        focusNode: _searchFocus,
                                        style: const TextStyle(
                                          color: AppTheme.text1,
                                        ),
                                        inputFormatters: [
                                          UpperCaseTextFormatter(),
                                        ],
                                        decoration: InputDecoration(
                                          labelText:
                                              'Buscar cliente (código o nombre)',
                                          prefixIcon: const Icon(Icons.search),
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical:
                                                    18, // 👈 un pelín más alto = más cómodo
                                              ),
                                          suffixIcon: _searchCtrl.text.isEmpty
                                              ? null
                                              : Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: 6,
                                                      ),
                                                  child: IconButton(
                                                    tooltip: 'Limpiar',
                                                    onPressed: () {
                                                      setState(() {
                                                        _searchCtrl.clear();
                                                        _searchResults = [];
                                                        _searching = false;
                                                      });
                                                      _removeSearchOverlay();
                                                    },
                                                    icon: const Icon(
                                                      Icons.close_rounded,
                                                    ),
                                                  ),
                                                ),
                                        ),
                                        onChanged: _onSearchChanged,
                                        onTap: () {
                                          if (_searchResults.isNotEmpty ||
                                              _searching) {
                                            _showSearchOverlay();
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const _DividerSoft(),

                          // Main page
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: _buildPage(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _title() {
    switch (_menu) {
      case MenuKey.clientes:
        return 'Clientes';
      case MenuKey.registro:
        return 'Registro';
      case MenuKey.prestamo:
        return _prestamoMode == PrestamoMode.nuevo
            ? 'Préstamo / Nuevo'
            : 'Préstamo / Renovación';
      case MenuKey.listaCobranza:
        return 'Lista de cobranza';
      case MenuKey.reporteCobranza:
        return 'Reporte de cobranza';
      case MenuKey.extra:
        return 'Extra';
      case MenuKey.configuracion:
        return 'Configuración';
    }
  }

  Widget _buildPage() {
    switch (_menu) {
      case MenuKey.clientes:
        return ClientesPage(
          onRegistrar: () {
            setState(() {
              _clienteParaRegistro = null; // ✅ IMPORTANTÍSIMO
              _menu = MenuKey.registro; // abre Registro
            });
          },

          onIrPrestamos: _irAPrestamoAuto,

          onAvales: (c, {bool nuevo = false}) {
            setState(() {
              _clienteParaRegistro = c;
              _menu = MenuKey.registro;
              _abrirFormularioAval = nuevo;
            });
          },
        );

      case MenuKey.registro:
        return RegistroPage(
          key: ValueKey(
            '${_clienteParaRegistro?.id ?? "nuevo"}-$_abrirFormularioAval',
          ),
          clienteInicial: _clienteParaRegistro,
          abrirFormularioAval: _abrirFormularioAval,
        );

      case MenuKey.prestamo:
        if (_clientePrestamo == null) {
          return const _PlaceholderCard(
            title: 'Préstamo',
            subtitle: 'Seleccione un cliente.',
          );
        }

        if (_resolviendoPrestamo) {
          return const _LoadingPlaceholderCard(
            title: 'Préstamo',
            subtitle: 'Revisando préstamo del cliente...',
          );
        }

        if (_prestamoError != null) {
          return _PlaceholderCard(title: 'Préstamo', subtitle: _prestamoError!);
        }

        return Prestamo(cliente: _clientePrestamo!);

      case MenuKey.listaCobranza:
        return const ListaCobranzaPage();

      case MenuKey.reporteCobranza:
        return const ReporteCobranzaPage();

      case MenuKey.extra:
        return const _PlaceholderCard(
          title: 'Extra',
          subtitle: 'Cositas adicionales: exportar Excel, respaldos, etc.',
        );

      case MenuKey.configuracion:
        return const _PlaceholderCard(
          title: 'Configuración',
          subtitle: 'Usuarios/roles, preferencias, cerrar sesión, etc.',
        );
    }
  }
}

class _DividerSoft extends StatelessWidget {
  const _DividerSoft();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: AppTheme.border.withValues(alpha: 0.7),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final bool expanded;
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  const _MenuTile({
    required this.expanded,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Material(
      color: selected ? AppTheme.surface2 : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppTheme.accent : Colors.transparent,
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? AppTheme.text1 : AppTheme.text2),
              if (expanded) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: t.titleMedium?.copyWith(
                      color: selected ? AppTheme.text1 : AppTheme.text2,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SubTile extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;

  const _SubTile({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Material(
      color: selected ? AppTheme.surface2 : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppTheme.accent
                  : AppTheme.border.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: t.bodyLarge?.copyWith(
              color: selected ? AppTheme.text1 : AppTheme.text2,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PlaceholderCard({required this.title, required this.subtitle});

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
          Text(title, style: t.titleLarge),
          const SizedBox(height: 6),
          Text(subtitle, style: t.bodyMedium),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _HeaderColapsado extends StatelessWidget {
  final VoidCallback onToggle;

  const _HeaderColapsado({required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppTheme.text1,
              size: 20,
            ),
          ),

          const SizedBox(width: 4),

          const Expanded(child: SizedBox()),

          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              tooltip: 'Expandir menú',
              onPressed: onToggle,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.keyboard_double_arrow_right_rounded,
                color: AppTheme.text2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderExpandido extends StatelessWidget {
  final String nombre;
  final String rol;
  final bool loading;
  final String? error;
  final VoidCallback onRefresh;
  final VoidCallback onToggle;

  const _HeaderExpandido({
    required this.nombre,
    required this.rol,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: const Icon(Icons.person_rounded, color: AppTheme.text1),
        ),
        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                Container(
                  height: 14,
                  width: 140,
                  decoration: BoxDecoration(
                    color: AppTheme.border.withOpacity(.55),
                    borderRadius: BorderRadius.circular(99),
                  ),
                )
              else
                Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleMedium?.copyWith(
                    color: AppTheme.text1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              const SizedBox(height: 6),

              // Chip rol + refresh
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2, // 👈 más compacto para evitar overflow
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surface2,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(
                        loading ? 'CARGANDO' : rol,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyMedium?.copyWith(
                          color: AppTheme.text2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Actualizar perfil',
                    onPressed: loading ? null : onRefresh,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: AppTheme.text2,
                    ),
                  ),
                ],
              ),

              if (error != null) ...[
                const SizedBox(height: 4),
                Text(
                  error!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyMedium?.copyWith(color: Colors.redAccent),
                ),
              ],
            ],
          ),
        ),

        IconButton(
          tooltip: 'Colapsar menú',
          onPressed: onToggle,
          icon: const Icon(
            Icons.keyboard_double_arrow_left_rounded,
            color: AppTheme.text2,
          ),
        ),
      ],
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

class _LoadingPlaceholderCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _LoadingPlaceholderCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
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
              Text(title, style: t.titleLarge),
              const SizedBox(height: 18),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.6),
              ),
              const SizedBox(height: 14),
              Text(subtitle, textAlign: TextAlign.center, style: t.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
