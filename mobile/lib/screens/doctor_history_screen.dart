import 'package:flutter/material.dart';
import '../core/api_client.dart';

class DoctorHistoryScreen extends StatefulWidget {
  const DoctorHistoryScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<DoctorHistoryScreen> createState() => _DoctorHistoryScreenState();
}

class _DoctorHistoryScreenState extends State<DoctorHistoryScreen> {
  List<dynamic> _historial = [];
  bool _cargando = true;
  String? _error;
  final TextEditingController _buscador = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  @override
  void dispose() { _buscador.dispose(); super.dispose(); }

  Future<void> _cargarHistorial([String filtro = '']) async {
    if (mounted) setState(() { _cargando = true; _error = null; });
    try {
      final query = filtro.isNotEmpty ? '?paciente=${Uri.encodeComponent(filtro)}' : '';
      final data = await widget.api.get('/citas/historial$query');
      if (!mounted) return;
      setState(() { _historial = data as List; _cargando = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _cargando = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Mi Historial de Pacientes'), backgroundColor: Colors.white, foregroundColor: const Color(0xFF1E3A8A), elevation: 0),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: TextField(
              controller: _buscador,
              onChanged: (v) => _cargarHistorial(v),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o CI...', prefixIcon: const Icon(Icons.search),
                suffixIcon: _buscador.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _buscador.clear(); _cargarHistorial(); }) : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                filled: true, fillColor: Colors.grey.shade100,
              ),
            ),
          ),
          Expanded(
            child: _cargando ? const Center(child: CircularProgressIndicator())
              : _error != null ? Center(child: Text('Error: $_error'))
              : _historial.isEmpty ? const Center(child: Text('No hay pacientes en tu historial.', style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: _historial.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final c = _historial[index] as Map;
                    final fecha = DateTime.tryParse(c['inicio'].toString());
                    final fechaStr = fecha != null ? '${fecha.day}/${fecha.month}/${fecha.year}' : '---';
                    final estado = c['estado']?.toString() ?? '';
                    final color = estado == 'ATENDIDA' ? Colors.green : Colors.orange;

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(Icons.person, color: color)),
                        title: Text(c['paciente'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('CI: ${c['documento'] ?? 'S/N'} · $fechaStr'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text(estado, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}