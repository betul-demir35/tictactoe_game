import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AdminApi {
  AdminApi({
    String? baseUrl,
    String? adminToken,
  })  : baseUrl = baseUrl ?? _defaultBaseUrl(),
        adminToken = adminToken ?? 'change_me_now';

  static String _defaultBaseUrl() {
    if (kIsWeb) return 'http://localhost:3000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://127.0.0.1:3000';
  }

  final String baseUrl;
  final String adminToken;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-admin-token': adminToken,
      };

  Map<String, String> get _publicHeaders => {
        'Content-Type': 'application/json',
      };

  // ---- AUTH (Public) ----

  Future<Map<String, dynamic>> registerUser({
    required String username,
    required String email,
    required String password,
  }) async {
    final r = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _publicHeaders,
      body: json.encode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );
    _ensureOk(r);
    return _decodeMap(r.body);
  }

  Future<Map<String, dynamic>> verifyUser({
    required String email,
    required String code,
  }) async {
    final r = await http.post(
      Uri.parse('$baseUrl/auth/verify'),
      headers: _publicHeaders,
      body: json.encode({'email': email, 'code': code}),
    );
    _ensureOk(r);
    return _decodeMap(r.body);
  }

  Future<Map<String, dynamic>> loginUser({
    required String email,
    required String password,
  }) async {
    final r = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _publicHeaders,
      body: json.encode({'email': email, 'password': password}),
    );
    _ensureOk(r);
    return _decodeMap(r.body);
  }

  // ---- Overview ----
  Future<Map<String, dynamic>> getOverview() async {
    final r = await http.get(Uri.parse('$baseUrl/admin/overview'), headers: _headers);
    _ensureOk(r);
    return _decodeMap(r.body);
  }

  // ---- Rooms ----
  Future<Map<String, dynamic>> getRooms({int page = 1, int limit = 25, String q = ''}) async {
    final u = Uri.parse('$baseUrl/admin/rooms').replace(queryParameters: {
      'page': '$page',
      'limit': '$limit',
      if (q.isNotEmpty) 'q': q,
    });
    final r = await http.get(u, headers: _headers);
    _ensureOk(r);
    return _decodeMap(r.body);
  }

  Future<Map<String, dynamic>> getRoom(String id) async {
    final r = await http.get(Uri.parse('$baseUrl/admin/rooms/$id'), headers: _headers);
    _ensureOk(r);
    return _decodeMap(r.body);
  }

  Future<void> deleteRoom(String id) async {
    final r = await http.delete(Uri.parse('$baseUrl/admin/rooms/$id'), headers: _headers);
    _ensureOk(r);
  }

  Future<void> kickPlayer(String roomId, {String? socketID, String? nickname}) async {
    final r = await http.post(
      Uri.parse('$baseUrl/admin/rooms/$roomId/kick'),
      headers: _headers,
      body: json.encode({'socketID': socketID, 'nickname': nickname}),
    );
    _ensureOk(r);
  }

  // ---- Scores ----
  Future<List<dynamic>> getScores({String? roomId}) async {
    final u = Uri.parse('$baseUrl/admin/scores')
        .replace(queryParameters: {if (roomId != null) 'roomId': roomId});
    final r = await http.get(u, headers: _headers);
    _ensureOk(r);
    return _decodeList(r.body);
  }

  Future<void> deleteScore(String roomId) async {
    final r = await http.delete(Uri.parse('$baseUrl/admin/scores/$roomId'), headers: _headers);
    _ensureOk(r);
  }

  // ---- Bans ----
  Future<List<dynamic>> getBans() async {
    final r = await http.get(Uri.parse('$baseUrl/admin/bans'), headers: _headers);
    _ensureOk(r);
    return _decodeList(r.body);
  }

  Future<void> addBan(String nickname, {String reason = ''}) async {
    final r = await http.post(
      Uri.parse('$baseUrl/admin/bans'),
      headers: _headers,
      body: json.encode({'nickname': nickname, 'reason': reason}),
    );
    _ensureOk(r);
  }

  Future<void> removeBan(String nickname) async {
    final r = await http.delete(Uri.parse('$baseUrl/admin/bans/$nickname'), headers: _headers);
    _ensureOk(r);
  }

  // ---- Users (Admin) ----
  Future<Map<String, dynamic>> getUsers({int page = 1, int limit = 25, String q = ''}) async {
    final u = Uri.parse('$baseUrl/admin/users').replace(queryParameters: {
      'page': '$page',
      'limit': '$limit',
      if (q.isNotEmpty) 'q': q,
    });
    final r = await http.get(u, headers: _headers);
    _ensureOk(r);
    return _decodeMap(r.body);
  }

  Future<void> deleteUser(String id) async {
    final r = await http.delete(Uri.parse('$baseUrl/admin/users/$id'), headers: _headers);
    _ensureOk(r);
  }

  // ---- Helpers ----
  void _ensureOk(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('Admin API error ${r.statusCode}: ${r.body}');
    }
  }

  Map<String, dynamic> _decodeMap(String body) {
    final decoded = json.decode(body);
    if (decoded is Map<String, dynamic>) {
      debugPrint('✅ AdminApi response: $decoded');
      return decoded;
    }
    throw Exception('Expected Map but got $decoded');
  }

  List<dynamic> _decodeList(String body) {
    final decoded = json.decode(body);
    if (decoded is List) {
      debugPrint('✅ AdminApi response: $decoded');
      return decoded;
    }
    throw Exception('Expected List but got $decoded');
  }
}
