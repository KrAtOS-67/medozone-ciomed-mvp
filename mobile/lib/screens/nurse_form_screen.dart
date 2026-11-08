import 'package:flutter/material.dart';
import '../core/api_client.dart';

class NurseFormScreen extends StatefulWidget {
  const NurseFormScreen({super.key, required this.api, required this.cita});
  final ApiClient api;
  final Map cita;

  @override
  State<NurseFormScreen> createState() => _NurseFormScreenState();
}

class _NurseFormScreenState extends State<NurseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _presion = TextEditingController();
  final _temperatura = TextEditingController();
  final _fc = TextEditingController();
  final _fr = TextEditingController();
  final _spo2 = TextEditingController();
  final _peso = TextEditingController();
  final _talla = TextEditingController();
  final _observaciones = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _presion.dispose(); _temperatura.dispose(); _fc.dispose(); _fr.dispose();
    _spo2.dispose(); _peso.dispose(); _talla.dispose(); _observaciones.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _guardando = true; _error = null; });
    try {
      await widget.api.post('/sesiones/preparar', {
        'citaId': widget.cita['id'],
        'presion': _presion.text.trim(),
        'temperatura': double.tryParse(_temperatura.text),
        'frecuenciaCardiaca': int.tryParse(_fc.text),
        'frecuenciaRespiratoria': int.tryParse(_fr.text),
        'saturacionOxigeno': int.tryParse(_spo2.text),
        'peso': double.tryParse(_peso.text),
        'talla': double.tryParse(_talla.text),
        'observaciones': 'Enfermería: ${_observaciones.text.trim()}',
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _input(String label, TextEditingController ctrl, IconData icon, {String? suffix}) {
    return TextFormField(
      controller: ctrl, keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), suffixText: suffix, border: const OutlineInputBorder(), filled: true, fillColor: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      appBar: AppBar(title: const Text('Signos Vitales'), backgroundColor: Colors.orange, foregroundColor: Colors.white),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Card(child: ListTile(leading: const Icon(Icons.person, color: Colors.orange), title: Text(widget.cita['paciente']?.toString() ?? 'Paciente', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: const Text('Preparación pre-tratamiento'))),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _input('Presión Arterial', _presion, Icons.favorite, suffix: 'mmHg')),
              const SizedBox(width: 10),
              Expanded(child: _input('Temperatura', _temperatura, Icons.thermostat, suffix: '°C')),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _input('Frec. Cardíaca', _fc, Icons.monitor_heart, suffix: 'lpm')),
              const SizedBox(width: 10),
              Expanded(child: _input('Frec. Respiratoria', _fr, Icons.air, suffix: 'rpm')),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _input('Saturación O₂', _spo2, Icons.water_drop, suffix: '%')),
              const SizedBox(width: 10),
              Expanded(child: _input('Peso', _peso, Icons.scale, suffix: 'kg')),
            ]),
            const SizedBox(height: 12),
            _input('Talla', _talla, Icons.height, suffix: 'cm'),
            const SizedBox(height: 16),
            TextFormField(controller: _observaciones, maxLines: 3, decoration: const InputDecoration(labelText: 'Observaciones de preparación', prefixIcon: Icon(Icons.notes), border: OutlineInputBorder(), filled: true, fillColor: Colors.white)),
            if (_error != null) ...[const SizedBox(height: 15), Text(_error!, style: const TextStyle(color: Colors.red))],
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _guardando ? null : _guardar,
                style: FilledButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                icon: _guardando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check),
                label: Text(_guardando ? 'Guardando...' : 'Guardar y Notificar al Médico', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}