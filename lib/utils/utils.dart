import 'package:flutter/material.dart';
import 'package:mp_tictactoe/provider/room_data_provider.dart';
import 'package:mp_tictactoe/resources/socket_methods.dart';
import 'package:provider/provider.dart';

// Kısa bilgi mesajı göster (SnackBar)
void showSnackBar(BuildContext context, String content) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(content)),
  );
}
// Oyun bitince sonucu gösteren dialog
void showGameDialog(BuildContext context, String text) {
  showDialog(
    barrierDismissible: false, // Dışarı tıklayınca kapanmaz
    context: context,
    builder: (ctx) {
      final provider = Provider.of<RoomDataProvider>(ctx, listen: false);
      return AlertDialog(
        title: Text(text),
        actions: [
          TextButton(
            onPressed: () {
              provider.setBoardActive(false); // Tıklamaları blokla
              SocketMethods().readyForNextRound(provider.roomData['_id']);
              Navigator.pop(ctx); // Sadece dialogu kapat
            },
            child: const Text('TEKRAR OYNA'),
          ),
        ],
      );
    },
  );
}
