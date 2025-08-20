// Flutter'ın temel UI bileşenlerini projeye ekler
import 'package:flutter/material.dart';

// Özel buton widget'ı (stateless)
class CustomButton extends StatelessWidget {
  // Butona tıklandığında çalışacak fonksiyon
  final VoidCallback onTap;

  // Buton üzerinde gösterilecek metin
  final String text;

  // Constructor (kurucu) – onTap ve text zorunlu parametrelerdir
  const CustomButton({
    Key? key,
    required this.onTap,
    required this.text,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Ekran genişliğini almak için MediaQuery kullanılır
    final width = MediaQuery.of(context).size.width;

    return Container(
      // Butonun arkasına mavi renkli hafif bir gölge efekti verir
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.blue, // Gölge rengi
            blurRadius: 5,      // Gölge yumuşaklığı
            spreadRadius: 0,    // Gölgenin yayılma oranı
          )
        ],
      ),
      child: ElevatedButton(
        // Butona tıklanınca çalışacak fonksiyon
        onPressed: onTap,
        // Butonun üstünde görünecek metin
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16, // Metin boyutu
          ),
        ),
        // Butonun boyut ve stilini özelleştirir
        style: ElevatedButton.styleFrom(
          minimumSize: Size(
            width, // Buton ekranın tamamı kadar geniş olacak
            50,    // Buton yüksekliği 50 piksel
          ),
        ),
      ),
    );
  }
}
