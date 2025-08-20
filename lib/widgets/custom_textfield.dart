// Flutter'ın temel UI bileşenlerini projeye ekler
import 'package:flutter/material.dart';

// Uygulamada kullanılacak sabit renkleri içeren dosya ekleniyor
import 'package:mp_tictactoe/utils/colors.dart';

// Özel metin kutusu widget'ı (stateless)
class CustomTextField extends StatelessWidget {
  // TextField'ın kontrolü için controller (metin girişi kontrolü)
  final TextEditingController controller;

  // Placeholder/hint olarak görünecek yazı
  final String hintText;

  // Sadece okunabilir mi? Varsayılan olarak false (kullanıcı yazabilir)
  final bool isReadOnly;

  // Constructor (kurucu) – controller ve hintText zorunlu, isReadOnly opsiyonel
  const CustomTextField({
    Key? key,
    required this.controller,
    required this.hintText,
    this.isReadOnly = false, // Varsayılan: yazılabilir
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      // Kutunun etrafına mavi gölge efekti verir
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.blue, // Gölge rengi
            blurRadius: 5,      // Gölge yumuşaklığı
            spreadRadius: 2,    // Gölgenin yayılma miktarı
          )
        ],
      ),
      child: TextField(
        // Kullanıcı yazamazsa true, yazabilirse false
        readOnly: isReadOnly,
        // Metin girişi controller'ı
        controller: controller,
        // TextField görünümünü ayarlar
        decoration: InputDecoration(
          fillColor: bgColor,      // Arka plan rengi (colors.dart dosyasından)
          filled: true,            // Arka plan dolu olsun mu?
          hintText: hintText,      // İçinde gri yazı (placeholder)
        ),
      ),
    );
  }
}
