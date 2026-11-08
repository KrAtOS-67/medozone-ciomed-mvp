import 'package:flutter/material.dart';
import '../core/api_client.dart';
import 'billing_form_screen.dart';
import 'billing_detail_screen.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  List<dynamic> _facturas = [];
  bool _cargando = true;
  String? _error;
  final TextEditingController _buscador = TextEditingController();
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _cargarFacturas();
  }

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  Future<void> _cargarFacturas() async {
    if (mounted) setState(() { _cargando = true; _error = null; });
    try {
      final data = await widget.api.get('/facturas');
      if (!mounted) return;
      setState(() { _facturas = data as List; _cargando = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _cargando = false; });
    }
  }

  Future<void> _nuevaFactura() async {
    final creada = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => BillingFormScreen(api: widget.api)));
    if (creada == true) _cargarFacturas();
  }

  Future<void> _verDetalle(Map factura) async {
    final actualizada = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => BillingDetailScreen(api: widget.api, factura: factura)));
    if (actualizada == true) _cargarFacturas();
  }

  List<dynamic> get _facturasFiltradas {
    if (_filtro.trim().isEmpty) return _facturas;
    final q = _filtro.toLowerCase().trim();
    return _facturas.where((f) {
      final factura = f as Map;
      final paciente = (factura['paciente']?.toString() ?? '').toLowerCase();
      final documento = (factura['documento']?.toString() ?? '').toLowerCase();
      final id = (factura['id']?.toString() ?? '').toLowerCase();
      return paciente.contains(q) || documento.contains(q) || id.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      appBar: AppBar(
        title: const Text('Facturación'),
        backgroundColor: Colors.white, foregroundColor: const Color(0xFF1E3A8A), elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF1E3A8A)), onPressed: _cargarFacturas)],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _nuevaFactura,
        backgroundColor: const Color(0xFF075BA8),
        foregroundColor: Colors.white,
        elevation: 4,
        tooltip: 'Nueva Factura',
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: TextField(
              controller: _buscador,
              onChanged: (v) => setState(() => _filtro = v),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, CI o N° factura...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF075BA8)),
                suffixIcon: _buscador.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () { _buscador.clear(); setState(() => _filtro = ''); },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                filled: true, fillColor: Colors.white,
              ),
            ),
          ),
          Expanded(child: _buildLista()),
        ],
      ),
    );
  }

  Widget _buildLista() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)));

    final lista = _facturasFiltradas;

    if (lista.isEmpty) {
      return Center(
        child: Text(
          _filtro.isEmpty ? 'No hay facturas emitidas.' : 'Sin resultados para "$_filtro".',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarFacturas,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 90),
        itemCount: lista.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final f = lista[index] as Map;
          final pendiente = (f['saldo'] as num) > 0;

          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Icon(Icons.receipt_long, color: pendiente ? Colors.orange : Colors.green, size: 30),
              title: Text('Factura #${f['id'].toString().padLeft(6, '0')}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f['paciente']?.toString() ?? ''),
                  if (f['documento'] != null)
                    Text('CI: ${f['documento']}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                  Text('Total: Bs ${f['total']} | Saldo: Bs ${f['saldo']}', style: TextStyle(color: pendiente ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
              isThreeLine: true,
              trailing: Icon(pendiente ? Icons.chevron_right : Icons.check_circle, color: pendiente ? Colors.grey : Colors.green),
              onTap: () => _verDetalle(f),
            ),
          );
        },
      ),
    );
  }
}