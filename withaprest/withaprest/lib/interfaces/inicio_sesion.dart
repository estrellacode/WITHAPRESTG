import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:withaprest/interfaces/principal.dart';
import 'package:withaprest/services/iniciosesion_services.dart';
import 'package:withaprest/theme/iniciotema.dart';

class InicioSesion extends StatefulWidget {
  const InicioSesion({super.key});

  @override
  State<InicioSesion> createState() => _InicioSesionState();
}

class _InicioSesionState extends State<InicioSesion> {
  final _formKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _remember = false;
  bool _hidePass = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final email = _emailCtrl.text.trim();
      final pass = _passCtrl.text;

      final service = InicioSesionService();

      final response = await service.login(email: email, password: pass);

      // Si por alguna razón no vino sesión
      if (response.session == null) {
        throw Exception('No se pudo iniciar sesión');
      }

      if (!mounted) return;

      // Opcional: traer perfil
      final perfil = await service.obtenerPerfil();
      debugPrint('Perfil: $perfil');

      // 🔥 IMPORTANTE:
      // NO navegues aquí.
      // AuthGate detectará la sesión automáticamente
      // y abrirá Principal solo.
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error inesperado: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.2,
                  colors: [Color(0xFF1A1E2A), AppTheme.bg],
                ),
              ),
            ),
          ),

          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          color: AppTheme.text2,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'WithaPrest',
                          style: t.titleLarge?.copyWith(color: AppTheme.text2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    Container(
                      padding: const EdgeInsets.fromLTRB(26, 26, 26, 18),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Inicio de sesión', style: t.headlineSmall),
                            const SizedBox(height: 6),
                            Text('Ingresa tu correo', style: t.bodyMedium),
                            const SizedBox(height: 22),

                            TextFormField(
                              controller: _emailCtrl,
                              style: const TextStyle(color: AppTheme.text1),
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Correo Electronico',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (v) {
                                final value = (v ?? '').trim();
                                if (value.isEmpty) {
                                  return 'Escribe tu correo';
                                }
                                if (!value.contains('@')) {
                                  return 'Correo inválido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _passCtrl,
                              style: const TextStyle(color: AppTheme.text1),
                              obscureText: _hidePass,
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () =>
                                      setState(() => _hidePass = !_hidePass),
                                  icon: Icon(
                                    _hidePass
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                ),
                              ),
                              validator: (v) {
                                final value = (v ?? '');
                                if (value.isEmpty) {
                                  return 'Escribe tu contraseña';
                                }
                                if (value.length < 4) {
                                  return 'Muy corta';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),

                            Row(
                              children: [
                                Checkbox(
                                  value: _remember,
                                  onChanged: (v) =>
                                      setState(() => _remember = v ?? false),
                                ),
                                Text(
                                  'Recordar usuario',
                                  style: t.bodyMedium?.copyWith(
                                    color: AppTheme.accent,
                                  ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () {},
                                  child: Text(
                                    '¿Olvidaste tu contraseña?',
                                    style: t.bodyMedium?.copyWith(
                                      color: AppTheme.accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            SizedBox(
                              height: 48,
                              child: FilledButton(
                                onPressed: _loading ? null : _signIn,
                                child: _loading
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Iniciar Sesión'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      '© 2026, WithAPresent todos los derechos reservados.',
                      style: t.bodyMedium?.copyWith(color: AppTheme.accent),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
