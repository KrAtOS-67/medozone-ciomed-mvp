import 'package:flutter/material.dart';
import '../core/api_client.dart';

class BillingFormScreen extends StatefulWidget {
  const BillingFormScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<BillingFormScreen> createState() => _BillingFormScreenState();
}

class _BillingFormScreenState extends State<BillingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _concepto = TextEditingController();
  final _total = TextEditingController();
  final _pacienteCtrl = TextEditingController();
  int? _pacienteId;

  late Future<dynamic> _pacientes;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pacientes = widget.api.get('/pacientes');
  }

  @override
  void dispose() {
    _concepto.dispose(); _total.dispose(); _pacienteCtrl.dispose();
    super.dispose();
  }

  void _abrirBuscadorPacientes(List<dynamic> pacientes) async {
    final seleccionado = await showModalBottomSheet<Map>(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _BuscadorPacienteModal(items: pacientes),
    );
    if (seleccionado != null) {
      setState(() {
        _pacienteId = (seleccionado['id'] as num).toInt();
        _pacienteCtrl.text = '${seleccionado['nombres']} ${seleccionado['apellidos']}';
      });
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pacienteId == null) { setState(() => _error = 'Selecciona un paciente.'); return; }

    setState(() { _guardando = true; _error = null; });
    try {
      await widget.api.post('/facturas', {
        'pacienteId': _pacienteId,
        'concepto': _concepto.text.trim(),
        'total': double.parse(_total.text),
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally { if (mounted) setState(() => _guardando = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva Factura'), backgroundColor: const Color(0xFF075BA8), foregroundColor: Colors.white),
      body: FutureBuilder<dynamic>(
        future: _pacientes,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          final pacientes = snapshot.data as List;

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                TextFormField(
                  controller: _pacienteCtrl,
                  readOnly: true,
                  onTap: () => _abrirBuscadorPacientes(pacientes),
                  decoration: InputDecoration(
                    labelText: 'Paciente *', hintText: 'Toca para buscar',
                    prefixIcon: const Icon(Icons.person_search),
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true, fillColor: Colors.grey.shade50,
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _concepto,
                  decoration: const InputDecoration(
                    labelText: 'Concepto / Detalle *', hintText: 'Ej: Ozonoterapia - 350, Cámara - 450',
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _total,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Total a pagar (Bs.) *',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    if (double.tryParse(v) == null) return 'Ingresa un número válido';
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 15),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _guardando ? null : _guardar,
                    style: FilledButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    icon: _guardando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save),
                    label: Text(_guardando ? 'Guardando...' : 'Emitir Factura'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BuscadorPacienteModal extends StatefulWidget {
  final List<dynamic> items;
  const _BuscadorPacienteModal({required this.items});
  @override
  State<_BuscadorPacienteModal> createState() => _BuscadorPacienteModalState();
}

class _BuscadorPacienteModalState extends State<_BuscadorPacienteModal> {
  String _filtro = '';
  @override
  Widget build(BuildContext context) {
    final filtrados = widget.items.where((i) {
      final map = i as Map;
      final texto = '${map['nombres']} ${map['apellidos']} ${map['documento']}'.toLowerCase();
      return texto.contains(_filtro.toLowerCase());
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7, maxChildSize: 0.9, minChildSize: 0.5, expand: false,
      builder: (_, scrollController) => Column(
        children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(hintText: 'Buscar por nombre o CI...', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              onChanged: (v) => setState(() => _filtro = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController, itemCount: filtrados.length,
              itemBuilder: (context, i) {
                final map = filtrados[i] as Map;
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text('${map['nombres']} ${map['apellidos']}'),
                  subtitle: Text('CI: ${map['documento'] ?? 'S/N'}'),
                  onTap: () => Navigator.pop(context, map),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}