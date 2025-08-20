// Flutter UI bileşenleri
import 'package:flutter/material.dart';

// Oda ve oyuncu verilerini sağlayan Provider
import 'package:mp_tictactoe/provider/room_data_provider.dart';

// Provider ile çalışmak için gerekli paket
import 'package:provider/provider.dart';

// Skor tablosunu gösteren widget (oyunun üst kısmında yer alır)
class Scoreboard extends StatelessWidget {
  const Scoreboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // RoomDataProvider üzerinden oyuncu verilerine erişiyoruz
    RoomDataProvider roomDataProvider = Provider.of<RoomDataProvider>(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center, // Satırı ortalar
      children: [
        // 1. oyuncunun ismi ve puanı
        Padding(
          padding: const EdgeInsets.all(30), // Dış boşluk
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // İçeriği dikey ortala
            children: [
              // Oyuncunun takma adı (bold ve büyük)
              Text(
                roomDataProvider.player1.nickname,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              // Oyuncunun puanı (tam sayı, beyaz renk)
              Text(
                roomDataProvider.player1.points.toInt().toString(),
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),

        // 2. oyuncunun ismi ve puanı
        Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                roomDataProvider.player2.nickname,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                roomDataProvider.player2.points.toInt().toString(),
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
