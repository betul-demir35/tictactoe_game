import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mp_tictactoe/screens/my_scores_screen.dart';
import 'package:mp_tictactoe/responsive/responsive.dart';
import 'package:mp_tictactoe/screens/create_room_screen.dart';
import 'package:mp_tictactoe/screens/join_room_screen.dart';
import 'package:mp_tictactoe/widgets/custom_button.dart';
import 'package:mp_tictactoe/admin/admin_api.dart';
import 'package:mp_tictactoe/resources/socket_client.dart';

class MainMenuScreen extends StatefulWidget {
  static String routeName = '/main-menu';
  const MainMenuScreen({Key? key}) : super(key: key);

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  bool _isJoined = false;
  String? _username; // AppBar’da gösterilecek
  String? _email;    // Skorlarım için gerekli
  String? _userId;

  @override
  void initState() {
    super.initState();
    _restoreLogin(); // prefs’ten kullanıcıyı geri yükle
  }

  Future<void> _restoreLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final email  = prefs.getString('email');
    final name   = prefs.getString('name');

    if (!mounted) return;

    if ((userId ?? '').isNotEmpty && (email ?? '').isNotEmpty) {
      final derivedName = (name != null && name.trim().isNotEmpty)
          ? name.trim()
          : email!.split('@').first;

      // Socket’i kimlikle bağla (server handshake.auth: name/email kullanıyor)
      try {
        await SocketClient().connectWithCredentials(
          name: derivedName,
          email: email!,
        );
        // Opsiyonel: backend bindUser istiyorsa
        try {
          SocketClient().socket.emit('bindUser', userId);
        } catch (_) {}
      } catch (_) {
        // socket bağlanamazsa UI’ı engellemeyelim
      }

      setState(() {
        _isJoined = true;
        _username = derivedName.isNotEmpty ? derivedName : email!;
        _email    = email;
        _userId   = userId;
      });
    }
  }

  // ---------- Navigasyon yardımcıları ----------
  void _createRoom(BuildContext context) =>
      _requireAuth(() => Navigator.pushNamed(context, CreateRoomScreen.routeName));

  void _joinRoom(BuildContext context) =>
      _requireAuth(() => Navigator.pushNamed(context, JoinRoomScreen.routeName));

  void _openRooms(BuildContext context) =>
      _requireAuth(() => Navigator.pushNamed(context, '/rooms'));

  void _openAdmin(BuildContext context) =>
      _requireAuth(() => Navigator.pushNamed(context, '/admin'));

  void _openScores(BuildContext context) {
    _requireAuth(() {
      final email = _email;
      if (email == null || email.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kullanıcı e-postası bulunamadı.')),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MyScoresScreen(email: email)),
      );
    });
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TicTacToe'),
        actions: [
          if (_username == null)
            TextButton.icon(
              onPressed: () => _openJoinDialog(context),
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Join'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            )
          else
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == "logout") {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('userId');
                  await prefs.remove('email');
                  await prefs.remove('name');

                  try { SocketClient().disconnect(); } catch (_) {}

                  if (!mounted) return;
                  setState(() {
                    _username = null;
                    _email = null;
                    _userId = null;
                    _isJoined = false;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Çıkış yapıldı.")),
                  );
                } else if (value == "scores") {
                  _openScores(context);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: "profile",
                  enabled: false,
                  child: Text(_username!),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: "scores",
                  child: Text("Skorlarım"),
                ),
                const PopupMenuItem(
                  value: "logout",
                  child: Text("Çıkış Yap"),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(child: Text(_username!)),
              ),
            ),
        ],
      ),
      body: Responsive(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomButton(onTap: () => _createRoom(context), text: 'ODA OLUŞTUR'),
            const SizedBox(height: 20),
            CustomButton(onTap: () => _joinRoom(context), text: 'ODAYA GİRİŞ YAP'),
            const SizedBox(height: 20),
            CustomButton(onTap: () => _openRooms(context), text: 'ODALAR'),
            const SizedBox(height: 20),
            CustomButton(onTap: () => _openAdmin(context), text: 'ADMIN'),
            const SizedBox(height: 20),
            CustomButton(onTap: () => _openScores(context), text: 'SKORLARIM'),
          ],
        ),
      ),
    );
  }

  // ---------- Join / Register / Verify dialog akışı ----------
  Future<void> _openJoinDialog(BuildContext context) async {
    final api = AdminApi();

    // Controller’ları lokal tutuyoruz; dialog kapanınca GC toplayacak.
    final emailC = TextEditingController();
    final passC  = TextEditingController();
    final nameC  = TextEditingController();
    final codeC  = TextEditingController();

    // Kullanıcı login mi register mı?
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Join'),
        content: const Text('Lütfen bir seçenek seçin'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'login'),
            child: const Text('Giriş Yap'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'register'),
            child: const Text('Kayıt Ol'),
          ),
        ],
      ),
    );

    // --- KAYIT OL ---
    if (choice == 'register') {
      final registered = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Kayıt Ol'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Kullanıcı Adı')),
              TextField(controller: emailC, decoration: const InputDecoration(labelText: 'E-posta')),
              TextField(controller: passC, decoration: const InputDecoration(labelText: 'Şifre'), obscureText: true),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await api.registerUser(
                    username: nameC.text.trim(),
                    email: emailC.text.trim(),
                    password: passC.text.trim(),
                  );
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Kayıt başarısız: $e')),
                  );
                }
              },
              child: const Text('Kayıt Ol'),
            ),
          ],
        ),
      );

      if (registered == true && context.mounted) {
        final verified = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Doğrulama'),
            content: TextField(
              controller: codeC,
              decoration: const InputDecoration(labelText: '6 Haneli Kod'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await api.verifyUser(
                      email: emailC.text.trim(),
                      code: codeC.text.trim(),
                    );
                    if (context.mounted) Navigator.pop(context, true);
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Doğrulama başarısız: $e')),
                    );
                  }
                },
                child: const Text('Doğrula'),
              ),
            ],
          ),
        );

        if (verified == true && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Doğrulama başarılı. Lütfen giriş yapın.')),
          );
          await _openJoinDialog(context); // doğrudan login diyaloğunu aç
        }
      }
    }

    // --- GİRİŞ YAP ---
    else if (choice == 'login') {
      final loggedIn = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Giriş Yap'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: emailC, decoration: const InputDecoration(labelText: 'E-posta')),
              TextField(controller: passC,  decoration: const InputDecoration(labelText: 'Şifre'), obscureText: true),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final resp = await api.loginUser(
                    email: emailC.text.trim(),
                    password: passC.text.trim(),
                  );

                  // {"message":"Giriş başarılı","user":{ "_id":"<hex24>", "email":"...", "username":"..." }}
                  final user   = Map<String, dynamic>.from(resp['user'] as Map);
                  final userId = (user['_id'] ?? '').toString();
                  final email  = (user['email'] ?? '').toString();
                  final name   = (user['username'] ?? user['name'] ?? '').toString();

                  if (userId.isEmpty || email.isEmpty) {
                    throw 'Sunucudan kullanıcı bilgisi eksik döndü.';
                  }

                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('userId', userId);
                  await prefs.setString('email', email);
                  if (name.isNotEmpty) await prefs.setString('name', name);

                  final derivedName = name.isNotEmpty ? name : email.split('@').first;

                  // Socket’i kimlikle bağla
                  try {
                    await SocketClient().connectWithCredentials(
                      name: derivedName,
                      email: email,
                    );
                    try { SocketClient().socket.emit('bindUser', userId); } catch (_) {}
                  } catch (_) {}

                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Giriş başarısız: $e')),
                  );
                }
              },
              child: const Text('Giriş Yap'),
            ),
          ],
        ),
      );

      if (loggedIn == true && context.mounted) {
        final prefs = await SharedPreferences.getInstance();
        final name  = prefs.getString('name');
        final email = prefs.getString('email');

        setState(() {
          _isJoined = true;
          _username = (name != null && name.trim().isNotEmpty) ? name : email;
          _email    = email;
          _userId   = prefs.getString('userId');
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Başarılı giriş!')),
        );
      }
    }
  }

  // ---------- ortak guard ----------
  void _requireAuth(VoidCallback onSuccess) {
    if (!_isJoined) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Üye değilsiniz, lütfen üye olun."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    onSuccess();
  }
}
