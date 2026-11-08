import 'package:flutter/material.dart';
import '../core/api_client.dart';

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  late Future<dynamic> _recursos;
  String _rol = '';
  bool _cargandoRol = true;

  @override
  void initState() {
    super.initState();
    _leerRol();
    _cargarRecursos();
  }

  void _leerRol() async {
    final rol = await widget.api.leerDato('rol');
    if (mounted) setState(() { _rol = rol ?? ''; _cargandoRol = false; });
  }

  void _cargarRecursos() {
    _recursos = widget.api.get('/recursos');
  }

  bool get _esAdmin => _rol == 'ADMIN';

  Future<void> _abrirFormularioNuevo() async {
    if (!_esAdmin) return;

    final creado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _NuevoRecursoModal(api: widget.api),
    );

    if (creado == true) {
      setState(() { _cargarRecursos(); });
    }
  }

  Future<void> _cambiarEstado(Map recurso) async {
    if (!_esAdmin) return;

    try {
      await widget.api.patch('/recursos/${recurso['id']}/estado', {'activo': !recurso['activo']});
      if (!mounted) return;
      setState(() { _cargarRecursos(); });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoRol) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8FC),
        appBar: AppBar(
          title: const Text('Equipos y Camillas'),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E3A8A),
          elevation: 0,
          bottom: const TabBar(
            labelColor: Color(0xFF075BA8),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF075BA8),
            tabs: [
              Tab(text: 'Ozonoterapia'),
              Tab(text: 'Cámara Hiperbárica'),
            ],
          ),
        ),
        body: FutureBuilder<dynamic>(
          future: _recursos,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
            
            final lista = snapshot.data as List? ?? [];
            
            return TabBarView(
              children: [
                _buildListaRecursos(lista.where((r) => r['tipoTratamiento'] == 'OZONOTERAPIA').toList()),
                _buildListaRecursos(lista.where((r) => r['tipoTratamiento'] == 'OXIGENOTERAPIA_HIPERBARICA').toList()),
              ],
            );
          },
        ),
        // El botón de añadir solo aparece si es ADMIN
        floatingActionButton: _esAdmin 
          ? FloatingActionButton.extended(
              onPressed: _abrirFormularioNuevo,
              backgroundColor: const Color(0xFF075BA8),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Añadir Equipo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      ),
    );
  }

  Widget _buildListaRecursos(List<dynamic> recursos) {
    if (recursos.isEmpty) {
      return const Center(child: Text('No hay equipos registrados.', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: recursos.length,
      itemBuilder: (context, index) {
        final r = recursos[index] as Map;
        final activo = r['activo'] == true;

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: activo ? Colors.blue.shade50 : Colors.grey.shade200,
              child: Icon(activo ? Icons.bed : Icons.bed_outlined, color: activo ? Colors.blue : Colors.grey),
            ),
            title: Text(
              r['nombre'].toString(), 
              style: TextStyle(fontWeight: FontWeight.bold, color: activo ? Colors.black87 : Colors.grey)
            ),
            subtitle: Text(activo ? 'Disponible' : 'Inactivo / Mantenimiento'),
            // El switch solo aparece si es ADMIN. Si es otro rol, solo ve el texto.
            trailing: _esAdmin 
              ? Switch(
                  value: activo,
                  activeColor: Colors.green,
                  onChanged: (v) => _cambiarEstado(r),
                )
              : Icon(
                  activo ? Icons.check_circle : Icons.cancel, 
                  color: activo ? Colors.green : Colors.red
                ),
          ),
        );
      },
    );
  }
}

// =========================================================
// MODAL PARA CREAR UN NUEVO RECURSO (Solo lo usa el Admin)
// =========================================================
class _NuevoRecursoModal extends StatefulWidget {
  const _NuevoRecursoModal({required this.api});
  final ApiClient api;

  @override
  State<_NuevoRecursoModal> createState() => _NuevoRecursoModalState();
}

class _NuevoRecursoModalState extends State<_NuevoRecursoModal> {
  final _nombreCtrl = TextEditingController();
  String _tipo = 'OZONOTERAPIA';
  bool _guardando = false;
  String? _error;

  @override
  void dispose() { _nombreCtrl.dispose(); super.dispose(); }

  Future<void> _guardar() async {
    if (_nombreCtrl.text.trim().isEmpty) {
      setState(() => _error = 'El nombre es obligatorio');
      return;
    }

    setState(() { _guardando = true; _error = null; });
    try {
      await widget.api.post('/recursos', {
        'nombre': _nombreCtrl.text.trim(),
        'tipoTratamiento': _tipo,
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Añadir Nuevo Equipo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
          const SizedBox(height: 20),
          TextField(
            controller: _nombreCtrl,
            decoration: InputDecoration(
              labelText: 'Nombre del equipo (ej. Camilla 4)',
              prefixIcon: const Icon(Icons.bed),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _tipo,
            decoration: InputDecoration(
              labelText: 'Área / Tratamiento',
              prefixIcon: const Icon(Icons.medical_services),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              DropdownMenuItem(value: 'OZONOTERAPIA', child: Text('Ozonoterapia')),
              DropdownMenuItem(value: 'OXIGENOTERAPIA_HIPERBARICA', child: Text('Cámara Hiperbárica')),
            ],
            onChanged: (v) => setState(() => _tipo = v!),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF075BA8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _guardando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save),
              label: Text(_guardando ? 'Guardando...' : 'Guardar Equipo', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}