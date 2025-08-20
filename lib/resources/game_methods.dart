import 'package:flutter/material.dart';
import 'package:mp_tictactoe/provider/room_data_provider.dart';
import 'package:mp_tictactoe/utils/utils.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart';

class GameMethods {
  // Kazananı ve beraberliği kontrol eder
  void checkWinner(BuildContext context, Socket socketClient) {
    RoomDataProvider provider = Provider.of<RoomDataProvider>(context, listen: false);

    String? winnerSymbol;

    // Satırları kontrol et
    for (int i = 0; i < 9; i += 3) {
      if (provider.displayElements[i] != '' &&
          provider.displayElements[i] == provider.displayElements[i + 1] &&
          provider.displayElements[i] == provider.displayElements[i + 2]) {
        winnerSymbol = provider.displayElements[i];
      }
    }

    // Sütunları kontrol et
    for (int i = 0; i < 3; i++) {
      if (provider.displayElements[i] != '' &&
          provider.displayElements[i] == provider.displayElements[i + 3] &&
          provider.displayElements[i] == provider.displayElements[i + 6]) {
        winnerSymbol = provider.displayElements[i];
      }
    }

    // Çaprazları kontrol et
    if (provider.displayElements[0] != '' &&
        provider.displayElements[0] == provider.displayElements[4] &&
        provider.displayElements[0] == provider.displayElements[8]) {
      winnerSymbol = provider.displayElements[0];
    }
    if (provider.displayElements[2] != '' &&
        provider.displayElements[2] == provider.displayElements[4] &&
        provider.displayElements[2] == provider.displayElements[6]) {
      winnerSymbol = provider.displayElements[2];
    }

    // KAZANAN VARSA
    if (winnerSymbol != null && provider.isBoardActive) {
      provider.setBoardActive(false);

      String winnerName;
      String winnerSocketId;
      if (provider.player1.playerType == winnerSymbol) {
        winnerName = provider.player1.nickname;
        winnerSocketId = provider.player1.socketID;
      } else {
        winnerName = provider.player2.nickname;
        winnerSocketId = provider.player2.socketID;
      }

      showGameDialog(context, '$winnerName won!');
      socketClient.emit('winner', {
        'winnerSocketId': winnerSocketId,
        'roomId': provider.roomData['_id'],
      });
      return;
    }

    // BERABERLİK (tüm kutular dolu VE kazanan yok)
    // BERABERLİK (tüm kutular dolu VE kazanan yok)
if (!provider.displayElements.contains('') &&
    winnerSymbol == null &&
    provider.isBoardActive) {
  provider.setBoardActive(false);
  showGameDialog(context, 'Draw');

  // >>> ÖNEMLİ: server’a haber ver ki skor/totals işlensin
  final roomId = provider.roomData['_id'];
  socketClient.emit('draw', { 'roomId': roomId });
  socketClient.emit('draw', { 'roomId': provider.roomData['_id'] });

}

  }

  // Tahtayı temizler (yeni round için)
  void clearBoard(BuildContext context) {
    final provider = Provider.of<RoomDataProvider>(context, listen: false);
    for (int i = 0; i < provider.displayElements.length; i++) {
      provider.updateDisplayElements(i, '');
    }
    provider.setFilledBoxesTo0();
  }
}
