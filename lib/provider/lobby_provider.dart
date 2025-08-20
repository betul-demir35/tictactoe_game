import 'package:flutter/material.dart';

class LobbyProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> get rooms => _rooms;

  void setRooms(List<dynamic> list) {
    _rooms = list
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    notifyListeners();
  }

  void clearRooms() {
    _rooms = [];
    notifyListeners();
  }
}
