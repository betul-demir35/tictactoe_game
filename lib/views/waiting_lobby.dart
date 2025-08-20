import 'package:flutter/material.dart';// Flutter'ın temel UI bileşenlerini projeye ekler
import 'package:mp_tictactoe/provider/room_data_provider.dart';// Oda verilerini yönetmek için kullanılan Provider dosyası ekleniyor
import 'package:mp_tictactoe/widgets/custom_textfield.dart';// Özel olarak hazırlanmış TextField widget'ı ekleniyor
import 'package:provider/provider.dart';// Provider altyapısı ile yönetim sağlamak için gerekli paket ekleniyor

// Oyuncu katılana kadar ekranda gözüken bekleme ekranı widget'ı 
class WaitingLobby extends StatefulWidget {
  // Kurucu (constructor)
  const WaitingLobby({Key? key}) : super(key: key);

  @override
  State<WaitingLobby> createState() => _WaitingLobbyState();
}

// StatefulWidget'ın state (durum) sınıfı
class _WaitingLobbyState extends State<WaitingLobby> {
  // Oda ID'sini gösterecek TextEditingController tanımlanıyor
  late TextEditingController roomIdController;

  // Widget ilk oluşturulduğunda çalışır (ekran açılır açılmaz)
  @override
  void initState() {
    super.initState();
    // RoomDataProvider üzerinden oda id'sini alıp TextEditingController'a ilk değer olarak veriyoruz
    roomIdController = TextEditingController(
      text: Provider.of<RoomDataProvider>(context, listen: false).roomData['_id'],
    );
  }

  // Widget ekrandan kaldırılırken çalışır (bellek temizliği için)
  @override
  void dispose() {
    super.dispose();
    // Kullanılmayan controller'ın hafızadan atılması sağlanır
    roomIdController.dispose();
  }

  // Widget'ın ekranda nasıl görüneceğini belirten fonksiyon
  @override
  Widget build(BuildContext context) {
    return Column(
      // Tüm içerik dikeyde ortalanır
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Üstte bilgilendirme metni (yeni oyuncu bekleniyor)
        const Text('DİĞER OYUNCUNUN GİRİŞ YAPMASI BEKLENİYOR...'),
        // Metin ile input alanı arasında boşluk bırakılır
        const SizedBox(height: 20),
        // Oda ID'sini gösteren, yalnızca okunabilir (readonly) özel bir textfield
        CustomTextField(
          controller: roomIdController, // Oda ID bilgisini gösterecek controller
          hintText: '',                 // Placeholder kullanılmamış (boş)
          isReadOnly: true,             // Kullanıcı bu alanı değiştiremez
        ),
      ],
    );
  }
}
