import 'package:flutter/material.dart';

import 'package:mp_tictactoe/resources/socket_methods.dart';
import 'package:mp_tictactoe/responsive/responsive.dart';
import 'package:mp_tictactoe/widgets/custom_button.dart';
import 'package:mp_tictactoe/widgets/custom_text.dart';
import 'package:mp_tictactoe/widgets/custom_textfield.dart';

class JoinRoomScreen extends StatefulWidget {
  static String routeName = '/join-room';
  const JoinRoomScreen({Key? key}) : super(key: key);

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final _roomIdC = TextEditingController();
  final _passwordC = TextEditingController();

  final _socket = SocketMethods();

  @override
  void initState() {
    super.initState();
    // Listener’ları tak ve (varsa) güncel oda listesini iste
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _socket.joinRoomSuccessListener(context);
      _socket.errorOccuredListener(context);
      _socket.updatePlayersStateListener(context);
      _socket.requestRooms();
    });
  }

  @override
  void dispose() {
    _roomIdC.dispose();
    _passwordC.dispose();
    super.dispose();
  }

  void _join() {
    FocusScope.of(context).unfocus();

    final roomId = _roomIdC.text.trim();
    final pwd = _passwordC.text.trim();

    if (roomId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen oda ID girin.')),
      );
      return;
    }

    // Sunucu şema: {roomId, password?}
    _socket.joinRoomById(roomId: roomId, password: pwd);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Responsive(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CustomText(
                shadows: [Shadow(blurRadius: 40, color: Colors.blue)],
                text: 'ODAYA KATIL',
                fontSize: 64,
              ),
              SizedBox(height: size.height * 0.06),

              // Oda ID
              CustomTextField(
                controller: _roomIdC,
                hintText: 'ODA ID (örn. 65f0a2...)',
              ),
              const SizedBox(height: 16),

              // Opsiyonel şifre
              CustomTextField(
                controller: _passwordC,
                hintText: 'ODA ŞİFRESİ (opsiyonel)',
                // Eğer CustomTextField’e obscureText eklediysen aç:
                // obscureText: true,
              ),
              SizedBox(height: size.height * 0.04),

              CustomButton(onTap: _join, text: 'KATIL'),
              const SizedBox(height: 16),

              // Kullanıcılar çoğu zaman ID ezberlemiyor; yönlendirme
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/rooms'),
                child: const Text('Oda listesini aç'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
