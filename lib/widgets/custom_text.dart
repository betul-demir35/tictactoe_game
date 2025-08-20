// Flutter'ın temel UI bileşenlerini projeye ekler
import 'package:flutter/material.dart';

// Özel başlık/metin widget'ı (stateless)
class CustomText extends StatelessWidget {
  // Metne gölge efekti vermek için kullanılacak gölge listesi
  final List<Shadow> shadows;

  // Ekranda gösterilecek metin
  final String text;

  // Metnin yazı boyutu
  final double fontSize;

  // Constructor (kurucu) – shadows, text ve fontSize zorunlu parametrelerdir
  const CustomText({
    Key? key,
    required this.shadows,
    required this.text,
    required this.fontSize,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      text, // Gösterilecek metin

      style: TextStyle(
        color: Colors.white,           // Metin rengi beyaz
        fontWeight: FontWeight.bold,   // Kalın yazı stili
        fontSize: fontSize,            // Metin boyutu
        shadows: shadows,              // Gölge efektleri (blur, renk vb.)
      ),
    );
  }
}
