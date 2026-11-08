import 'package:flutter/material.dart';
import '../core/api_client.dart';

class SessionFormScreen extends StatefulWidget {
  const SessionFormScreen({super.key, required this.api, required this.cita, this.sesion});
  final ApiClient api;
  final Map cita;
  final Map? sesion;

  @override
  State<SessionFormScreen> createState() => _SessionFormScreenState();
}

class _SessionFormScreenState extends State<SessionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dosis = TextEditingController();
  final _duracion = TextEditingController(text: '60');
  final _observaciones = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() { _dosis.dispose(); _duracion.dispose(); _observaciones.dispose(); super.dispose(); }

  double? _convertirDecimal(String valor) => double.tryParse(valor.trim().replaceAll(',', '.'));

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final dosis = _convertirDecimal(_dosis.text);
    final duracion = int.tryParse(_duracion.text.trim());
    if (dosis == null || duracion == null) return;

    setState(() { _guardando = true; _error = null; });
    try {
      if (widget.sesion != null) {
        await widget.api.patch('/sesiones/${widget.sesion!['id']}/completar', {
          'dosis': dosis, 'duracionMinutos': duracion, 'observaciones': _observaciones.text.trim(),
        });
      } else {
        await widget.api.post('/sesiones', {
          'citaId': widget.cita['id'], 'dosis': dosis, 'duracionMinutos': duracion, 'observaciones': _observaciones.text.trim(),
        });
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally { if (mounted) setState(() => _guardando = false); }
  }

  Widget _vitalChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.orange.shade200)),
      child: Column(children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sesion = widget.sesion;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      appBar: AppBar(title: Text(sesion != null ? 'Completar Sesión' : 'Registrar Sesión'), backgroundColor: const Color(0xFF075BA8), foregroundColor: Colors.white),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            if (sesion != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.medical_information, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Signos Vitales (Enfermería)', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14)),
                    ]),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: [
                        _vitalChip('PRESIÓN', sesion['presion']?.toString() ?? '-'),
                        _vitalChip('TEMP', '${sesion['temperatura'] ?? '-'} °C'),
                        _vitalChip('F.C.', '${sesion['fc'] ?? '-'} lpm'),
                        _vitalChip('F.R.', '${sesion['fr'] ?? '-'} rpm'),
                        _vitalChip('SpO2', '${sesion['spo2'] ?? '-'} %'),
                        _vitalChip('PESO', '${sesion['peso'] ?? '-'} kg'),
                        _vitalChip('TALLA', '${sesion['talla'] ?? '-'} cm'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: Colors.grey),
                  SizedBox(width: 8),
                  Expanded(child: Text('Sin preparar por enfermería. Registre los datos completos.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13))),
                ]),
              ),
              const SizedBox(height: 20),
            ],
            Card(
              child: ListTile(
                leading: const Icon(Icons.person, color: Color(0xFF075BA8)),
                title: Text(widget.cita['paciente']?.toString() ?? 'Paciente', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Tratamiento: ${(widget.cita['tipoTratamiento'] ?? '').toString().replaceAll('_', ' ')}'),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _dosis,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Dosis aplicada *', prefixIcon: Icon(Icons.science_outlined), border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
              validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _duracion,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Duración en minutos *', prefixIcon: Icon(Icons.timer_outlined), border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 1 || n > 240) return 'Entre 1 y 240';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _observaciones, maxLines: 4,
              decoration: const InputDecoration(labelText: 'Observaciones clínicas', alignLabelWithHint: true, prefixIcon: Icon(Icons.notes_outlined), border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _guardando ? null : _guardar,
                style: FilledButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                icon: _guardando ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check_circle),
                label: Text(_guardando ? 'Guardando...' : 'Finalizar Sesión', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}