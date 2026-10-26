import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5000/api',
  );

  String get baseUrl => configuredBaseUrl.endsWith('/')
      ? configuredBaseUrl.substring(0, configuredBaseUrl.length - 1)
      : configuredBaseUrl;

  String? _token;
  bool get hasToken => _token != null && _token!.isNotEmpty;

  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hrms_token', token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('hrms_token');
  }

  Future<Map<String, dynamic>?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('hrms_token');
    if (!hasToken) return null;
    try {
      final result = Map<String, dynamic>.from(await get('/auth/me') as Map);
      return Map<String, dynamic>.from(result['user'] as Map);
    } catch (_) {
      await clearToken();
      return null;
    }
  }

  Future<dynamic> get(String path) => _request('GET', path);
  Future<dynamic> post(String path, [Map<String, dynamic>? body]) => _request('POST', path, body);
  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) => _request('PATCH', path, body);
  Future<dynamic> delete(String path) => _request('DELETE', path);

  Future<Uint8List> getBytes(String path) async {
    final uri = Uri.parse(baseUrl + path);
    final headers = <String, String>{'Accept': 'image/*'};
    if (hasToken) headers['Authorization'] = 'Bearer ' + _token!;
    final response = await http.get(uri, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) await clearToken();
      dynamic decoded;
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        decoded = null;
      }
      final message = decoded is Map ? decoded['message']?.toString() : null;
      throw Exception(message == null || message.isEmpty
          ? 'Image could not be loaded (' + response.statusCode.toString() + ').'
          : message);
    }
    return response.bodyBytes;
  }

  Future<dynamic> _request(String method, String path, [Map<String, dynamic>? body]) async {
    final uri = Uri.parse(baseUrl + path);
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (hasToken) headers['Authorization'] = 'Bearer ' + _token!;
    late http.Response response;
    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: headers);
        break;
      case 'POST':
        response = await http.post(uri, headers: headers, body: body == null ? null : jsonEncode(body));
        break;
      case 'PATCH':
        response = await http.patch(uri, headers: headers, body: body == null ? null : jsonEncode(body));
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: headers);
        break;
      default:
        throw ArgumentError('Unsupported HTTP method: ' + method);
    }

    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) await clearToken();
      final message = decoded is Map ? decoded['message']?.toString() : null;
      throw Exception(message == null || message.isEmpty
          ? 'Request failed (' + response.statusCode.toString() + ').'
          : message);
    }
    return decoded;
  }
}
