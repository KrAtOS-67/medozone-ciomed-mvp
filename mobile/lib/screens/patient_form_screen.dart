import 'package:flutter/material.dart';
import '../core/api_client.dart';

class PatientFormScreen extends StatefulWidget {
  const PatientFormScreen({super.key, required this.api, this.paciente});
  final ApiClient api;
  final Map? paciente;

  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();
  final _documento = TextEditingController();
  final _telefono = TextEditingController();
  final _email = TextEditingController();
  final _observaciones = TextEditingController();
  final _fechaNacimientoCtrl = TextEditingController();

  DateTime? _fechaNacimiento;
  bool _guardando = false;
  String? _error;

  bool get _editando => widget.paciente != null;

  @override
  void initState() {
    super.initState();
    final paciente = widget.paciente;
    if (paciente != null) {
      _nombres.text = (paciente['nombres'] ?? '').toString();
      _apellidos.text = (paciente['apellidos'] ?? '').toString();
      _documento.text = (paciente['documento'] ?? '').toString();
      _telefono.text = (paciente['telefono'] ?? '').toString();
      _email.text = (paciente['email'] ?? '').toString();
      _observaciones.text = (paciente['observaciones'] ?? '').toString();
      
      if (paciente['fechaNacimiento'] != null) {
        _fechaNacimiento = DateTime.tryParse(paciente['fechaNacimiento'].toString());
        if (_fechaNacimiento != null) {
          _fechaNacimientoCtrl.text = '${_fechaNacimiento!.day.toString().padLeft(2, '0')}/${_fechaNacimiento!.month.toString().padLeft(2, '0')}/${_fechaNacimiento!.year}';
        }
      }
    }
  }

  @override
  void dispose() {
    _nombres.dispose(); _apellidos.dispose(); _documento.dispose();
    _telefono.dispose(); _email.dispose(); _observaciones.dispose(); _fechaNacimientoCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(context: context, initialDate: _fechaNacimiento ?? DateTime(1990), firstDate: DateTime(1900), lastDate: DateTime.now());
    if (fecha != null) {
      setState(() {
        _fechaNacimiento = fecha;
        _fechaNacimientoCtrl.text = '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
      });
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _guardando = true; _error = null; });

    final fechaStr = _fechaNacimiento != null ? '${_fechaNacimiento!.year}-${_fechaNacimiento!.month.toString().padLeft(2, '0')}-${_fechaNacimiento!.day.toString().padLeft(2, '0')}' : null;
    final datos = <String, dynamic>{
      'nombres': _nombres.text.trim(), 'apellidos': _apellidos.text.trim(),
      'documento': _documento.text.trim(), 'telefono': _telefono.text.trim(),
      'email': _email.text.trim(), 'fechaNacimiento': fechaStr, 'observaciones': _observaciones.text.trim(),
      'estadoClinico': _editando ? widget.paciente!['estadoClinico'] : 'NUEVO', // Se mantiene el estado actual
    };

    try {
      if (_editando) { await widget.api.put('/pacientes/${widget.paciente!['id']}', datos); } 
      else { await widget.api.post('/pacientes', datos); }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _campo({required String titulo, required TextEditingController controlador, String? textoAyuda, TextInputType tipo = TextInputType.text, int maxLineas = 1, String? Function(String?)? validar, IconData? icono}) {
    return TextFormField(
      controller: controlador, enabled: !_guardando, keyboardType: tipo, maxLines: maxLineas,
      textCapitalization: tipo == TextInputType.emailAddress ? TextCapitalization.none : TextCapitalization.sentences,
      decoration: InputDecoration(labelText: titulo, hintText: textoAyuda, prefixIcon: icono != null ? Icon(icono) : null, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      validator: validar,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editando ? 'Editar paciente' : 'Nuevo paciente'), backgroundColor: const Color(0xFF075BA8), foregroundColor: Colors.white),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(_editando ? 'Actualizar datos personales' : 'Datos personales', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 22),
            _campo(titulo: 'Nombres *', controlador: _nombres, icono: Icons.person_outline, validar: (v) => v!.isEmpty ? 'Requerido' : null),
            const SizedBox(height: 16),
            _campo(titulo: 'Apellidos *', controlador: _apellidos, icono: Icons.person, validar: (v) => v!.isEmpty ? 'Requerido' : null),
            const SizedBox(height: 16),
            _campo(titulo: 'CI / Documento', controlador: _documento, icono: Icons.badge_outlined),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fechaNacimientoCtrl, readOnly: true, onTap: _guardando ? null : _seleccionarFecha,
              decoration: InputDecoration(labelText: 'Fecha de nacimiento', hintText: 'Toca para seleccionar', prefixIcon: const Icon(Icons.cake_outlined), suffixIcon: const Icon(Icons.calendar_month, size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 16),
            _campo(titulo: 'Teléfono', controlador: _telefono, tipo: TextInputType.phone, icono: Icons.phone_outlined),
            const SizedBox(height: 16),
            _campo(titulo: 'Correo electrónico', controlador: _email, tipo: TextInputType.emailAddress, icono: Icons.email_outlined),
            const SizedBox(height: 16),
            _campo(titulo: 'Observaciones', controlador: _observaciones, maxLineas: 3, icono: Icons.notes),
            if (_error != null) ...[const SizedBox(height: 15), Text(_error!, style: const TextStyle(color: Colors.red))],
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _guardando ? null : _guardar,
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF075BA8)),
                icon: _guardando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save),
                label: Text(_editando ? 'Guardar cambios' : 'Guardar paciente'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}