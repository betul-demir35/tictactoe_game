import 'package:flutter/material.dart';
import 'package:mp_tictactoe/models/player.dart';

class RoomDataProvider extends ChangeNotifier {
  // ---- Core room state ----
  Map<String, dynamic> _roomData = {};
  List<String> _displayElements = List<String>.filled(9, '');
  int _filledBoxes = 0;

  // ---- Players ----
  Player _player1 =
      Player(nickname: '', socketID: '', points: 0, playerType: 'X');
  Player _player2 =
      Player(nickname: '', socketID: '', points: 0, playerType: 'O');

  // ---- Score totals ----
  Map<String, int> _totals = {'X': 0, 'O': 0, 'draw': 0};

  // ---- Board lock ----
  bool _isBoardActive = true;

  // ---- Yeni: isJoined ----
  bool _isJoined = false;

  // ===== Getters =====
  Map<String, dynamic> get roomData => _roomData;
  List<String> get displayElements => _displayElements;
  int get filledBoxes => _filledBoxes;
  Player get player1 => _player1;
  Player get player2 => _player2;
  Map<String, int> get totals => _totals;
  bool get isBoardActive => _isBoardActive;
  bool get isJoined => _isJoined;

  // ===== Mutations =====

  void updateRoomData(Map<String, dynamic> data) {
    _roomData = Map<String, dynamic>.from(data);

    // --- Oyuncuları uygula
    final rawPlayers = data['players'];
    if (rawPlayers is List) {
      final players = rawPlayers
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _applyPlayersList(players, notify: false);
    }

    // --- Yeni: isJoined bilgisini uygula
    if (data.containsKey('isJoined')) {
      _isJoined = data['isJoined'] == true;
    }

    notifyListeners();
  }

  void updatePlayer1(Map<String, dynamic> player1Data, {bool notify = true}) {
    _player1 = Player.fromMap(Map<String, dynamic>.from(player1Data));
    if (notify) notifyListeners();
  }

  void updatePlayer2(Map<String, dynamic> player2Data, {bool notify = true}) {
    _player2 = Player.fromMap(Map<String, dynamic>.from(player2Data));
    if (notify) notifyListeners();
  }

  void _applyPlayersList(List<Map<String, dynamic>> players,
      {bool notify = true}) {
    final px = players.firstWhere(
      (p) => p['playerType'] == 'X',
      orElse: () => <String, dynamic>{},
    );
    final po = players.firstWhere(
      (p) => p['playerType'] == 'O',
      orElse: () => <String, dynamic>{},
    );

    if (px.isNotEmpty) _player1 = Player.fromMap(px);
    if (po.isNotEmpty) _player2 = Player.fromMap(po);

    if (notify) notifyListeners();
  }

  // Tek hücre güncelle
  void updateDisplayElements(int index, String choice) {
    if (index < 0 || index >= 9) return;
    if (_displayElements[index].isEmpty && choice.isNotEmpty) {
      _filledBoxes += 1;
    }
    _displayElements[index] = choice;
    notifyListeners();
  }

  // Tüm board’u set et
  void setBoard(List<String> board) {
    if (board.length != 9) return;
    _displayElements = List<String>.from(board);
    _filledBoxes = _displayElements.where((c) => c.isNotEmpty).length;
    notifyListeners();
  }

  void resetBoard() {
    _displayElements = List<String>.filled(9, '');
    _filledBoxes = 0;
    notifyListeners();
  }

  void setFilledBoxesTo0() {
    _filledBoxes = 0;
    notifyListeners();
  }

  // ----- SCORE EVENTS -----

  void applyPointIncrease(Map<String, dynamic> player) {
    final String type = ((player['playerType'] as String?) ?? '').toUpperCase();
    final int pts = (player['points'] as num?)?.toInt() ?? 0;
    final String nick = (player['nickname'] as String?) ?? '';
    final String sid = (player['socketID'] as String?) ?? '';

    if (type == 'X') {
      _player1 = Player(
        nickname: nick.isNotEmpty ? nick : _player1.nickname,
        socketID: sid.isNotEmpty ? sid : _player1.socketID,
        points: pts,
        playerType: 'X',
      );
    } else if (type == 'O') {
      _player2 = Player(
        nickname: nick.isNotEmpty ? nick : _player2.nickname,
        socketID: sid.isNotEmpty ? sid : _player2.socketID,
        points: pts,
        playerType: 'O',
      );
    }
    notifyListeners();
  }

  void applyScoreUpdated(Map<String, dynamic> data) {
    final totalsMap = Map<String, dynamic>.from(data['totals'] ?? {});
    _totals = {
      'X': (totalsMap['X'] as num?)?.toInt() ?? 0,
      'O': (totalsMap['O'] as num?)?.toInt() ?? 0,
      'draw': (totalsMap['draw'] as num?)?.toInt() ?? 0,
    };

    final rawList = (data['players'] as List?) ?? const [];
    final players = rawList
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    _applyPlayersList(players, notify: false);

    // --- Yeni: isJoined güncellemesi
    if (data.containsKey('isJoined')) {
      _isJoined = data['isJoined'] == true;
    }

    notifyListeners();
  }

  // Board kilidi
  void setBoardActive(bool value) {
    _isBoardActive = value;
    notifyListeners();
  }

  // Yeni: isJoined setter
  void setIsJoined(bool value) {
    _isJoined = value;
    notifyListeners();
  }
}
