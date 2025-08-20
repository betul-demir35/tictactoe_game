// Tek bir Socket.IO istemcisi üzerinden tüm uygulamayı konuşturur.
// AuthProvider YOK: kimliği SharedPreferences'tan ya da parametreyle alır.
// NOT: auth bilgisi URL query üzerinden gönderilir; options/opts KULLANILMIYOR.

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
String _socketHost() {
  // Desktop/Web
  if (kIsWeb) return 'http://localhost:3000';
  try {
    if (Platform.isAndroid) return 'http://10.0.2.2:3000'; // <<< ZORLA
    if (Platform.isIOS) return 'http://127.0.0.1:3000';
    // Windows/macOS/Linux desktop
    return 'http://127.0.0.1:3000';
  } catch (_) {
    return 'http://127.0.0.1:3000';
  }
  print('SOCKET HOST => ${_socketHost()}');
}

class SocketClient {
  static final SocketClient _i = SocketClient._internal();
  factory SocketClient() => _i;

  IO.Socket? _socket;
  IO.Socket get socket => _socket!;

  SocketClient._internal() {
    _createSocket(); // kimliksiz, autoConnect=false
  }

 IO.Socket _createSocket({String? name, String? email}) {
  final base = _socketHost();
  String url = base;
  if (name != null && email != null) {
    final q = 'name=${Uri.encodeComponent(name)}&email=${Uri.encodeComponent(email)}';
    url = '$base/?$q';
  }

  final s = IO.io(
    url,
    <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'forceNew': true, // <<< ÖNEMLİ
    },
  );

  s.onConnect((_) => print('SOCKET connected: ${s.id}'));
  s.onDisconnect((_) => print('SOCKET disconnected'));
  s.on('connect_error', (data) => print('connect_error: $data'));

  _socket = s;
  return s;
}

  

  /// Login sonrasında kimlikle bağlan
Future<void> connectWithCredentials({ required String name, required String email }) async {
  final prev = _socket;
  if (prev != null && prev.connected) {
    print('SOCKET reconnect requested but already connected (${prev.id}) -> disconnect & recreate');
    try { prev.disconnect(); } catch (_) {}
  }
  _createSocket(name: name, email: email);
  _socket!.connect();
}

  /// Uygulama açılışında prefs’ten bağlan
  Future<void> connectFromPrefs() async {
     if (_socket != null && _socket!.connected) {
    print('SOCKET already connected (${_socket!.id}), skipping connectFromPrefs()');
    return;
  }
    final p = await SharedPreferences.getInstance();
    String? name = p.getString('name');
    final email = p.getString('email');
    if (email == null || email.isEmpty) return;
    name = (name == null || name.trim().isEmpty) ? email.split('@').first : name;
    await connectWithCredentials(name: name, email: email);
  }

  /// Kimliği güncelle + yeniden bağlan
  Future<void> updateCredentialsAndReconnect({
    required String name,
    required String email,
  }) async {
    await connectWithCredentials(name: name, email: email);
  }

  void disconnect() {
    final s = _socket;
    if (s != null && s.connected) s.disconnect();
  }
}