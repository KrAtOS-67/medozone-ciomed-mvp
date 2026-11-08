import 'package:flutter/material.dart';
import '../core/api_client.dart';

class UserFormScreen extends StatefulWidget {
  const UserFormScreen({super.key, required this.api, this.usuario});
  final ApiClient api;
  final Map<String, dynamic>? usuario;

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _telefono = TextEditingController();
  final _especialidad = TextEditingController();
  final _password = TextEditingController();

  String _rol = 'RECEPCIONISTA';
  List<String> _areasSeleccionadas = [];
  bool _ocultarPassword = true;
  bool _guardando = false;
  String? _error;

  bool get _esEdicion => widget.usuario != null;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      final u = widget.usuario!;
      _username.text = u['username']?.toString() ?? '';
      _fullName.text = u['fullName']?.toString() ?? '';
      _email.text = u['email']?.toString() ?? '';
      _telefono.text = u['telefono']?.toString() ?? '';
      _especialidad.text = u['especialidad']?.toString() ?? '';
      _rol = u['role']?.toString() ?? 'RECEPCIONISTA';
      
      if (u['areas'] != null) {
        _areasSeleccionadas = List<String>.from(u['areas'].map((e) => e.toString()));
      }
    }
  }

  @override
  void dispose() {
    _username.dispose(); _fullName.dispose(); _email.dispose();
    _telefono.dispose(); _especialidad.dispose(); _password.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _guardando = true; _error = null; });

    final datos = <String, dynamic>{
      'fullName': _fullName.text.trim(),
      'email': _email.text.trim(),
      'telefono': _telefono.text.trim(),
      'especialidad': _especialidad.text.trim(),
      'role': _rol,
      'areas': _areasSeleccionadas,
    };

    try {
      if (_esEdicion) {
        await widget.api.put('/users/${widget.usuario!['id']}', datos);
      } else {
        datos['username'] = _username.text.trim();
        datos['password'] = _password.text;
        await widget.api.post('/users', datos);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_esEdicion ? 'Editar usuario' : 'Nuevo usuario')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            TextFormField(
              controller: _username, enabled: !_esEdicion && !_guardando,
              decoration: const InputDecoration(labelText: 'Usuario *', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().length < 3) ? 'Mínimo 3 caracteres' : null,
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _fullName, enabled: !_guardando,
              decoration: const InputDecoration(labelText: 'Nombre completo *', prefixIcon: Icon(Icons.badge_outlined), border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el nombre' : null,
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _email, enabled: !_guardando,
              decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _telefono, enabled: !_guardando, keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono', prefixIcon: Icon(Icons.phone_outlined), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _rol, isExpanded: true,
              decoration: const InputDecoration(labelText: 'Rol *', prefixIcon: Icon(Icons.shield_outlined), border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'ADMIN', child: Text('Administrador')),
                DropdownMenuItem(value: 'MEDICO', child: Text('Médico')),
                DropdownMenuItem(value: 'ENFERMERA', child: Text('Enfermera')),
                DropdownMenuItem(value: 'RECEPCIONISTA', child: Text('Recepcionista')),
              ],
              onChanged: _guardando ? null : (v) => setState(() => _rol = v ?? 'RECEPCIONISTA'),
            ),
            const SizedBox(height: 15),
            
            if (_rol == 'MEDICO') ...[
              TextFormField(
                controller: _especialidad, enabled: !_guardando,
                decoration: const InputDecoration(labelText: 'Especialidad médica', hintText: 'Ej: Medicina Hiperbárica', prefixIcon: Icon(Icons.medical_information_outlined), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              const Text('Áreas de atención *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              CheckboxListTile(
                title: const Text('Ozonoterapia'),
                value: _areasSeleccionadas.contains('OZONOTERAPIA'),
                onChanged: _guardando ? null : (v) {
                  setState(() {
                    if (v == true) _areasSeleccionadas.add('OZONOTERAPIA');
                    else _areasSeleccionadas.remove('OZONOTERAPIA');
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('Oxigenoterapia Hiperbárica'),
                value: _areasSeleccionadas.contains('OXIGENOTERAPIA_HIPERBARICA'),
                onChanged: _guardando ? null : (v) {
                  setState(() {
                    if (v == true) _areasSeleccionadas.add('OXIGENOTERAPIA_HIPERBARICA');
                    else _areasSeleccionadas.remove('OXIGENOTERAPIA_HIPERBARICA');
                  });
                },
              ),
              const SizedBox(height: 15),
            ],

            if (!_esEdicion)
              TextFormField(
                controller: _password, enabled: !_guardando, obscureText: _ocultarPassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña *',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(icon: Icon(_ocultarPassword ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _ocultarPassword = !_ocultarPassword)),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.length < 8) ? 'Mínimo 8 caracteres' : null,
              ),
            if (_error != null) ...[const SizedBox(height: 15), Text(_error!, style: const TextStyle(color: Colors.red))],
            const SizedBox(height: 24),
            SizedBox(height: 52, child: FilledButton.icon(onPressed: _guardando ? null : _guardar, icon: const Icon(Icons.save), label: Text(_guardando ? 'Guardando...' : 'Guardar'))),
          ],
        ),
      ),
    );
  }
}