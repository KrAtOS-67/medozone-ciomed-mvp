import 'package:flutter/material.dart';
import '../core/api_client.dart';
import 'user_form_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  // Manejo directo de la lista
  List<dynamic> _usuarios = [];
  bool _cargando = true;
  String? _error;

  final TextEditingController _buscador = TextEditingController();
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  Future<void> _cargarUsuarios() async {
    if (mounted) setState(() { _cargando = true; _error = null; });
    try {
      final data = await widget.api.get('/users');
      if (!mounted) return;
      setState(() {
        _usuarios = data as List;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _cargando = false;
      });
    }
  }

  Future<void> _nuevoUsuario() async {
    final creado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => UserFormScreen(api: widget.api)),
    );
    if (!mounted) return;
    if (creado == true) _cargarUsuarios(); // Recarga al volver
  }

  Future<void> _editar(Map user) async {
    final editado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => UserFormScreen(
          api: widget.api,
          usuario: Map<String, dynamic>.from(user),
        ),
      ),
    );
    if (!mounted) return;
    if (editado == true) _cargarUsuarios(); // Recarga al volver
  }

  Future<void> _cambiarEstado(Map user) async {
    final activo = user['active'] == true;
    final username = user['username']?.toString() ?? '';
    final accion = activo ? 'desactivar' : 'activar';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿${activo ? "Desactivar" : "Activar"} usuario?'),
        content: Text('El usuario "$username" ${activo ? "no podrá iniciar sesión" : "podrá volver a iniciar sesión"}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(activo ? 'Desactivar' : 'Activar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    try {
      await widget.api.patch('/users/${user['id']}/$accion');
      if (!mounted) return;
      _cargarUsuarios(); // Recarga al instante
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Usuario $username ${activo ? "desactivado" : "activado"}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}')),
      );
    }
  }

  Color _colorRol(String rol) {
    switch (rol) {
      case 'ADMIN': return const Color(0xFF075BA8);
      case 'MEDICO': return Colors.teal;
      case 'ENFERMERA': return Colors.purple;
      case 'RECEPCIONISTA': return Colors.orange;
      default: return Colors.grey;
    }
  }

  IconData _iconoRol(String rol) {
    switch (rol) {
      case 'ADMIN': return Icons.admin_panel_settings;
      case 'MEDICO': return Icons.medical_services;
      case 'ENFERMERA': return Icons.local_hospital;
      case 'RECEPCIONISTA': return Icons.support_agent;
      default: return Icons.person;
    }
  }

  // Normalizar texto para ignorar tildes en el buscador
  String _normalizar(String texto) {
    return texto.toLowerCase()
        .replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i')
        .replaceAll('ó', 'o').replaceAll('ú', 'u').replaceAll('ñ', 'n');
  }

  @override
  Widget build(BuildContext context) {
    // Filtrado de la lista en tiempo real
    final listaFiltrada = _usuarios.where((u) {
      final m = u as Map;
      final nombre = _normalizar(m['fullName']?.toString() ?? '');
      final username = _normalizar(m['username']?.toString() ?? '');
      final rol = _normalizar(m['role']?.toString() ?? '');
      final filtroNorm = _normalizar(_filtro);
      return nombre.contains(filtroNorm) || username.contains(filtroNorm) || rol.contains(filtroNorm);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
        actions: [
          IconButton(
            onPressed: _cargando ? null : _cargarUsuarios,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevoUsuario,
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo usuario'),
      ),
      body: Column(
        children: [
          // BUSCADOR
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: TextField(
              controller: _buscador,
              onChanged: (value) => setState(() => _filtro = value),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, usuario o rol...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _filtro.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _buscador.clear();
                          setState(() => _filtro = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
          ),

          // LISTA DE USUARIOS
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)))
                    : listaFiltrada.isEmpty
                        ? Center(
                            child: Text(
                              _filtro.isEmpty ? 'No hay usuarios registrados.' : 'No se encontraron usuarios.',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _cargarUsuarios,
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 90),
                              itemCount: listaFiltrada.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final u = Map<String, dynamic>.from(listaFiltrada[i] as Map);
                                final rol = u['role']?.toString() ?? '';
                                final activo = u['active'] == true;
                                final color = _colorRol(rol);

                                return Card(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: color.withValues(alpha: 0.15),
                                      child: Icon(_iconoRol(rol), color: color),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            u['fullName']?.toString() ?? u['username']?.toString() ?? '',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        if (!activo)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade200,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Text('INACTIVO',
                                                style: TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.bold)),
                                          ),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('@${u['username']} · $rol'),
                                        if ((u['email']?.toString() ?? '').isNotEmpty)
                                          Text(u['email'].toString(), style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                                        if ((u['telefono']?.toString() ?? '').isNotEmpty)
                                          Text('Tel: ${u['telefono']}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                                        // Mostrar áreas si es médico
                                        if (u['areas'] != null && (u['areas'] as List).isNotEmpty)
                                          Text('Áreas: ${(u['areas'] as List).join(", ").replaceAll("_", " ")}',
                                            style: const TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (action) {
                                        if (action == 'editar') _editar(u);
                                        if (action == 'estado') _cambiarEstado(u);
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(
                                          value: 'editar',
                                          child: ListTile(
                                            leading: Icon(Icons.edit),
                                            title: Text('Editar'),
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'estado',
                                          child: ListTile(
                                            leading: Icon(activo ? Icons.block : Icons.check_circle),
                                            title: Text(activo ? 'Desactivar' : 'Activar'),
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () => _editar(u),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}