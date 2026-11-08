import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_client.dart';

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  static const _colorPrincipal = Color(0xFF075BA8);
  static const _colorFondo = Color(0xFFE4F1FC);

  // Llaves de los formularios
  final _formUsuario = GlobalKey<FormState>();
  final _formCodigo = GlobalKey<FormState>();
  final _formReset = GlobalKey<FormState>();

  final _usuario = TextEditingController();
  final _codigo = TextEditingController();
  final _contrasena = TextEditingController();
  final _confirmar = TextEditingController();

  int _paso = 0; // 0 = usuario, 1 = código, 2 = contraseña
  bool _cargando = false;
  bool _ocultar = true;
  String? _error;
  String? _ok;

  @override
  void dispose() {
    _usuario.dispose();
    _codigo.dispose();
    _contrasena.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _solicitar() async {
    if (_cargando) return;
    if (!_formUsuario.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _error = null;
      _ok = null;
    });

    try {
      await widget.api.forgotPassword(_usuario.text.trim());
      if (!mounted) return;
      setState(() {
        _paso = 1;
        _ok = 'Si el usuario existe, enviamos un código de 6 dígitos '
            'al correo registrado. Válido por 10 minutos.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _verificarCodigo() async {
    if (_cargando) return;
    if (!_formCodigo.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _error = null;
      _ok = null;
    });

    try {
      await widget.api.verifyCode(_codigo.text.trim());
      if (!mounted) return;
      setState(() {
        _paso = 2;
        _ok = 'Código verificado. Ingresa tu nueva contraseña.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _restablecer() async {
    if (_cargando) return;
    if (!_formReset.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _error = null;
      _ok = null;
    });

    try {
      await widget.api.resetPassword(
        _codigo.text.trim(),
        _contrasena.text,
      );
      if (!mounted) return;
      setState(() {
        _ok = 'Contraseña actualizada correctamente. Ya puedes iniciar sesión.';
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: _colorPrincipal,
        title: const Text('Recuperar contraseña'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(26),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CircleAvatar(
                    radius: 42,
                    backgroundColor: _colorFondo,
                    child: Icon(Icons.lock_reset, color: _colorPrincipal, size: 46),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    _paso == 0
                        ? 'Ingresa tu usuario y te enviaremos un código al correo.'
                        : _paso == 1
                            ? 'Ingresa el código de 6 dígitos que recibiste.'
                            : 'Ingresa tu nueva contraseña.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.blueGrey, fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  // RENDERIZADO DINÁMICO SEGÚN EL PASO
                  if (_paso == 0) _vistaSolicitar(),
                  if (_paso == 1) _vistaCodigo(),
                  if (_paso == 2) _vistaRestablecer(),

                  if (_ok != null) ...[
                    const SizedBox(height: 14),
                    _alerta(_ok!, Icons.check_circle_outline, Colors.green),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    _alerta(_error!, Icons.error_outline, Colors.red),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _vistaSolicitar() {
    return Form(
      key: _formUsuario,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _usuario,
            enabled: !_cargando,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Usuario',
              hintText: 'Ingresa tu usuario',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tu usuario' : null,
            onFieldSubmitted: (_) => _solicitar(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _cargando ? null : _solicitar,
              style: FilledButton.styleFrom(
                backgroundColor: _colorPrincipal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _cargando
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Enviar código', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vistaCodigo() {
    return Form(
      key: _formCodigo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _codigo,
            enabled: !_cargando,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.bold),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Código de verificación',
              hintText: '123456',
              prefixIcon: const Icon(Icons.pin_outlined),
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Ingresa el código';
              if (v.length != 6) return 'El código tiene 6 dígitos';
              return null;
            },
            onFieldSubmitted: (_) => _verificarCodigo(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _cargando ? null : _verificarCodigo,
              style: FilledButton.styleFrom(
                backgroundColor: _colorPrincipal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _cargando
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Verificar código', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vistaRestablecer() { 
    return Form(
      key: _formReset,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _contrasena,
            enabled: !_cargando,
            obscureText: _ocultar,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Nueva contraseña',
              helperText: 'Mínimo 8 caracteres',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _ocultar ? 'Mostrar contraseña' : 'Ocultar contraseña',
                onPressed: _cargando ? null : () => setState(() => _ocultar = !_ocultar),
                icon: Icon(_ocultar ? Icons.visibility : Icons.visibility_off),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) => (v == null || v.length < 8) ? 'Mínimo 8 caracteres' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmar,
            enabled: !_cargando,
            obscureText: _ocultar,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Confirmar contraseña',
              prefixIcon: const Icon(Icons.lock_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) => v != _contrasena.text ? 'Las contraseñas no coinciden' : null,
            onFieldSubmitted: (_) => _restablecer(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _cargando ? null : _restablecer,
              style: FilledButton.styleFrom(
                backgroundColor: _colorPrincipal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _cargando
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Cambiar contraseña', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
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