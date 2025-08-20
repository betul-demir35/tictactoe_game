// Flutter'ın temel UI bileşenlerini içeren paket
import 'package:flutter/material.dart';

// Responsive adında özel bir StatelessWidget tanımlıyoruz
// Bu widget, belirli bir maksimum genişliğe sahip responsive (duyarlı) bir tasarım sağlar
class Responsive extends StatelessWidget {
  // Dışarıdan gelen widget (örneğin bir sayfa, form, liste vs.)
  final Widget child;

  // Constructor: child parametresi zorunlu olarak alınır
  const Responsive({
    Key? key,
    required this.child,  // İçerik olarak gösterilecek widget
  }) : super(key: key);    // Üst sınıf olan StatelessWidget’a key gönderilir

  // Widget’ın ekrana çizildiği yer
  @override
  Widget build(BuildContext context) {
    return Center(  // Ortalamayı sağlar
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 600,  // Maksimum genişlik 600 piksel olarak sınırlandırılır
        ),
        child: child,     // İçerik buraya yerleştirilir
      ),
    );
  }
}
