import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api_client.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codigoCtrl = TextEditingController();
  final _contrasenaCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();

  bool _enviandoCodigo = true;
  bool _guardando = false;
  bool _ocultar = true;
  String? _error;
  String? _ok;
  String? _usuario;

  @override
  void initState() {
    super.initState();
    _enviarCodigoInicial();
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _contrasenaCtrl.dispose();
    _confirmarCtrl.dispose();
    super.dispose();
  }

  // Al abrir la pantalla, envía el código al email del usuario logueado
  Future<void> _enviarCodigoInicial() async {
    final usuario = await widget.api.leerDato('usuario');
    if (!mounted) return;
    if (usuario == null || usuario.isEmpty) {
      setState(() {
        _enviandoCodigo = false;
        _error = 'No se pudo identificar el usuario actual.';
      });
      return;
    }
    _usuario = usuario;
    try {
      await widget.api.forgotPassword(usuario);
      if (!mounted) return;
      setState(() {
        _enviandoCodigo = false;
        _ok = 'Enviamos un código de 6 dígitos al correo registrado en tu cuenta.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enviandoCodigo = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _reenviarCodigo() async {
    if (_usuario == null) return;
    setState(() {
      _enviandoCodigo = true;
      _error = null;
      _ok = null;
    });
    try {
      await widget.api.forgotPassword(_usuario!);
      if (!mounted) return;
      setState(() {
        _ok = 'Se envió un nuevo código a tu correo.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _enviandoCodigo = false);
    }
  }

  Future<void> _cambiarContrasena() async {
    if (_guardando) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _guardando = true;
      _error = null;
      _ok = null;
    });

    try {
      await widget.api.resetPassword(
        _codigoCtrl.text.trim(),
        _contrasenaCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _ok = 'áContraseña actualizada correctamente!';
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const colorPrincipal = Color(0xFF075BA8);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: colorPrincipal,
        title: const Text('Cambiar contraseña'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(26),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CircleAvatar(
                      radius: 42,
                      backgroundColor: Color(0xFFE4F1FC),
                      child: Icon(Icons.key, color: colorPrincipal, size: 46),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      _enviandoCodigo
                          ? 'Enviando código a tu correo...'
                          : 'Te enviamos un código de verificación al correo de tu cuenta.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.blueGrey, fontSize: 14),
                    ),
                    const SizedBox(height: 24),

                    if (_enviandoCodigo) ...[
                      const Center(child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: CircularProgressIndicator(),
                      )),
                    ] else ...[
                      // Código de 6 dígitos
                      TextFormField(
                        controller: _codigoCtrl,
                        enabled: !_guardando,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(
                          fontSize: 28,
                          letterSpacing: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Código de verificación',
                          hintText: '123456',
                          counterText: '',
                          prefixIcon: const Icon(Icons.pin_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Ingresa el código';
                          if (v.length != 6) return 'El código tiene 6 dígitos';
                          return null;
                        },
                        onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                      ),
                      const SizedBox(height: 16),

                      // Nueva contraseña
                      TextFormField(
                        controller: _contrasenaCtrl,
                        enabled: !_guardando,
                        obscureText: _ocultar,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: 'Nueva contraseña',
                          helperText: 'Mínimo 8 caracteres',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_ocultar ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _ocultar = !_ocultar),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.length < 8) return 'Mínimo 8 caracteres';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Confirmar
                      TextFormField(
                        controller: _confirmarCtrl,
                        enabled: !_guardando,
                        obscureText: _ocultar,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: 'Confirmar nueva contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) {
                          if (v != _contrasenaCtrl.text) return 'Las contraseñas no coinciden';
                          return null;
                        },
                        onFieldSubmitted: (_) => _cambiarContrasena(),
                      ),
                      const SizedBox(height: 12),

                      // Botón reenviar código
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _guardando ? null : _reenviarCodigo,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Reenviar código'),
                        ),
                      ),

                      if (_ok != null) ...[
                        const SizedBox(height: 12),
                        _alerta(_ok!, Icons.check_circle_outline, Colors.green),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        _alerta(_error!, Icons.error_outline, Colors.red),
                      ],

                      const SizedBox(height: 20),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _guardando ? null : _cambiarContrasena,
                          style: FilledButton.styleFrom(
                            backgroundColor: colorPrincipal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _guardando
                              ? const SizedBox(
                                  height: 22, width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(
                                  'Cambiar contraseña',
                                  style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _alerta(String texto, IconData icono, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texto, style: TextStyle(color: color.shade800, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}