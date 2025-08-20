import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mp_tictactoe/resources/socket_methods.dart';
import 'package:mp_tictactoe/responsive/responsive.dart';
import 'package:mp_tictactoe/widgets/custom_button.dart';
import 'package:mp_tictactoe/widgets/custom_text.dart';
import 'package:mp_tictactoe/widgets/custom_textfield.dart';

class CreateRoomScreen extends StatefulWidget {
  static String routeName = '/create-room';
  const CreateRoomScreen({Key? key}) : super(key: key);

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final List<String> _levels = ['easy', 'medium', 'hard', 'besiktas'];
  String _selectedLevel = 'easy';

  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final SocketMethods _socket = SocketMethods();
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    // Ek olarak server “createRoomSuccess” yayarsa yakalayalım (navigasyon yedek).
    _socket.createRoomSuccessListener(context);
    _socket.errorOccuredListener(context);
    _socket.updateRoomListener(context);
    _socket.updatePlayersStateListener(context);
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    // Giriş kontrolü (login sonrası kaydedilen userId)
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce giriş yapmalısınız')),
      );
      return;
    }

    final roomName = _roomNameController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _creating = true);
    final result = await _socket.createRoomAck(
      level: _selectedLevel,
      roomName: roomName.isEmpty ? null : roomName,
      password: password.isEmpty ? null : password,
      timeout: const Duration(seconds: 6),
    );
    if (!mounted) return;
    setState(() => _creating = false);

    if (result.ok) {
      // Server createRoomSuccess da yayabilir; ACK döndüyse direkt lobby/game’e geç.
      // Eğer GameScreen route’unda room provider’ı dinliyorsan success listener zaten push yapacak.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oda oluşturuldu!')),
      );
      // Navigasyonu createRoomSuccess listener’ına bırakmak istersen bu kısmı kaldırabilirsin.
      // Burada hızlı bir yönlendirme istersen:
      // Navigator.pushReplacementNamed(context, GameScreen.routeName);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Sunucudan yanıt alınamadı')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Responsive(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: size.height),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CustomText(
                    shadows: [Shadow(blurRadius: 40, color: Colors.blue)],
                    text: 'ODANI OLUŞTUR',
                    fontSize: 70,
                  ),
                  SizedBox(height: size.height * 0.06),

                  DropdownButton<String>(
                    value: _selectedLevel,
                    onChanged: (v) => setState(() => _selectedLevel = v!),
                    items: _levels
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e.toUpperCase()),
                            ))
                        .toList(),
                  ),
                  SizedBox(height: size.height * 0.02),

                  CustomTextField(
                    controller: _roomNameController,
                    hintText: 'ODA ADI',
                  ),
                  const SizedBox(height: 20),

                  CustomTextField(
                    controller: _passwordController,
                    hintText: 'ODA ŞİFRESİ',
                  ),

                  SizedBox(height: size.height * 0.045),

                  CustomButton(
  onTap: _creating
      ? () {}                 // buton kilitliyken no-op (null vermiyoruz)
      : () { _createRoom(); }, // async fonksiyonu çağırıyoruz
  text: _creating ? 'OLUŞTURULUYOR…' : 'OLUŞTUR',
),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
