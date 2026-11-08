import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api',
  );

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String get _base => baseUrl.replaceFirst(RegExp(r'/+$'), '');

  Future<Map<String, String>> _headers({bool autenticado = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json; charset=utf-8',
    };
    if (autenticado) {
      final token = await _storage.read(key: 'token');
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  dynamic _procesar(http.Response response) {
    // ⚠️ SIEMPRE decodificar bytes como UTF-8 (no usar response.body)
    final body = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
    dynamic data;
    if (body.isNotEmpty) {
      try {
        data = jsonDecode(body);
      } catch (_) {
        data = body;
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return data;

    String message = 'Error HTTP ${response.statusCode}';
    if (data is Map) {
      message = (data['detail'] ?? data['message'] ?? data['title'] ?? message)
          .toString();
    } else if (data is String && data.isNotEmpty) {
      message = data;
    }
    throw Exception(message);
  }

  // ============================================================
  // AUTH
  // ============================================================
  Future<Map<String, dynamic>> login(String usuario, String contrasena) async {
    final response = await http.post(
      Uri.parse('$_base/auth/login'),
      headers: await _headers(autenticado: false),
      body: utf8.encode(jsonEncode({
        'usuario': usuario,
        'contrasena': contrasena,
      })),
    );
    final data = _procesar(response) as Map<String, dynamic>;
    await _storage.write(key: 'token', value: data['token'].toString());
    await _storage.write(key: 'usuario', value: data['usuario'].toString());
    await _storage.write(key: 'nombre', value: data['nombre'].toString());
    await _storage.write(key: 'rol', value: data['rol'].toString());
    return data;
  }

  Future<void> forgotPassword(String usuario) async {
    final response = await http.post(
      Uri.parse('$_base/auth/forgot-password'),
      headers: await _headers(autenticado: false),
      body: utf8.encode(jsonEncode({'usuario': usuario})),
    );
    _procesar(response);
  }

  Future<void> verifyCode(String codigo) async {
    final response = await http.post(
      Uri.parse('$_base/auth/verify-code'),
      headers: await _headers(autenticado: false),
      body: utf8.encode(jsonEncode({'codigo': codigo})),
    );
    _procesar(response);
  }

  Future<void> resetPassword(String token, String nuevaContrasena) async {
    final response = await http.post(
      Uri.parse('$_base/auth/reset-password'),
      headers: await _headers(autenticado: false),
      body: utf8.encode(jsonEncode({
        'token': token,
        'nuevaContrasena': nuevaContrasena,
      })),
    );
    _procesar(response);
  }

  // ============================================================
  // HTTP VERBS
  // ============================================================
  Future<dynamic> get(String path) async {
    final response = await http.get(
      Uri.parse('$_base$path'),
      headers: await _headers(),
    );
    return _procesar(response);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$_base$path'),
      headers: await _headers(),
      body: utf8.encode(jsonEncode(body)),
    );
    return _procesar(response);
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('$_base$path'),
      headers: await _headers(),
      body: utf8.encode(jsonEncode(body)),
    );
    return _procesar(response);
  }

  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) async {
    final response = await http.patch(
      Uri.parse('$_base$path'),
      headers: await _headers(),
      body: body != null ? utf8.encode(jsonEncode(body)) : null,
    );
    return _procesar(response);
  }

  // ============================================================
  // STORAGE
  // ============================================================
  Future<String?> leerDato(String key) => _storage.read(key: key);

  Future<void> cerrarSesion() => _storage.deleteAll();

  Future<bool> tieneSesion() async =>
      (await _storage.read(key: 'token')) != null;

  Future<bool> validarSesion() async {
    final token = await _storage.read(key: 'token');
    if (token == null || token.isEmpty) return false;
    try {
      await get('/auth/me');
      return true;
    } catch (_) {
      await cerrarSesion();
      return false;
    }
  }
}