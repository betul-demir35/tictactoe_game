import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'package:mp_tictactoe/provider/lobby_provider.dart';
import 'package:mp_tictactoe/provider/room_data_provider.dart';
import 'package:mp_tictactoe/resources/game_methods.dart';
import 'package:mp_tictactoe/resources/socket_client.dart';
import 'package:mp_tictactoe/screens/game_screen.dart';
import 'package:mp_tictactoe/utils/utils.dart';

typedef SocketEventHandler = void Function(dynamic);

class CreateRoomResult {
  final bool ok;
  final dynamic room;
  final String? error;
  CreateRoomResult.ok(this.room) : ok = true, error = null;
  CreateRoomResult.err(this.error) : ok = false, room = null;
}

class SocketMethods {
  SocketMethods();
  IO.Socket get socketClient => socket;
  // Tek ve paylaşılan socket
    IO.Socket get socket => SocketClient().socket;
  final Set<String> _boundEvents = <String>{};

  // ====== HELPERS ======
  void _off(String event) {
    socket.off(event);
    _boundEvents.remove(event);
  }

  void _on(String event, SocketEventHandler handler) {
    socket.off(event);
    socket.on(event, handler);
    _boundEvents.add(event);
  }

  void removeAllListeners() {
    for (final e in _boundEvents.toList()) {
      socket.off(e);
    }
    _boundEvents.clear();
  }
void leaveRoom(String roomId) {
  if (roomId.isEmpty) return;
  socketClient.emit('leaveRoom', {'roomId': roomId});
}
  Future<void> _ensureConnected() async {
    if (socket.connected) return;
    final c = Completer<void>();
    void ok(_) {
      if (!c.isCompleted) c.complete();
    }
    socket.once('connect', ok);
    socket.connect();
    try {
      await c.future.timeout(const Duration(seconds: 3));
    } catch (_) {}
    socket.off('connect', ok);
  }

  String _roomIdOf(Map r) =>
      (r['id'] ?? r['_id'] ?? r['roomId'] ?? '').toString();

  // ====== EMITS ======
  void requestRooms() {
    socket.emit('listRooms');
  }

  void createRoom({
    required String level,
    String? roomName,
    String? password,
  }) {
    socket.emit('createRoom', {
      'level': level,
      if (roomName != null && roomName.isNotEmpty) 'name': roomName,
      if (password != null && password.isNotEmpty) 'password': password,
    });
  }

  Future<CreateRoomResult> createRoomAck({
    required String level,
    String? roomName,
    String? password,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    await _ensureConnected();

    final payload = <String, dynamic>{
      'level': level,
      if (roomName != null && roomName.isNotEmpty) 'name': roomName,
      if (password != null && password.isNotEmpty) 'password': password,
    };

    final completer = Completer<CreateRoomResult>();
    bool finished = false;

    socket.emitWithAck('createRoom', payload, ack: (data) {
      if (finished) return;
      finished = true;
      if (data is Map && data['ok'] == true) {
        completer.complete(CreateRoomResult.ok(data['room']));
      } else {
        final err = (data is Map)
            ? (data['message']?.toString() ?? 'Bilinmeyen hata')
            : 'Bilinmeyen hata';
        completer.complete(CreateRoomResult.err(err));
      }
    });

    Future.delayed(timeout, () {
      if (!finished) {
        finished = true;
        completer.complete(CreateRoomResult.err('Zaman aşımı'));
      }
    });

    return completer.future;
  }

  void joinRoomById({
    required String roomId,
    String password = '',
  }) {
    if (roomId.isEmpty) return;
    socket.emit('joinRoom', {'roomId': roomId, 'password': password});
  }

  // Eski akış için (artık kullanılmıyor)
  void joinRoom({
    required String nickname,
    String password = '',
    required String userId,
  }) {
    showDebugPrint('joinRoom(nickname,userId) kullanılmıyor.');
  }

  void tapGrid(int index, String roomId, List<String> displayElements) {
    if (index < 0 || index >= 9) return;
    if (displayElements[index] != '') return;
    if (roomId.isEmpty) return;
    socket.emit('tap', {'index': index, 'roomId': roomId});
  }

  void startHardModeShuffle(String roomId, List<String> board) {
    if (roomId.isEmpty) return;
    socket.emit('startHardModeShuffle', {'roomId': roomId, 'board': board});
  }

  void stopHardModeShuffle(String roomId) {
    if (roomId.isEmpty) return;
    socket.emit('stopHardModeShuffle', {'roomId': roomId});
  }

  void readyForNextRound(String roomId) {
    if (roomId.isEmpty) return;
    socket.emit('readyForNextRound', {'roomId': roomId});
  }

  // ====== LISTENERS ======
  void roomsListListener(BuildContext context) {
    void handler(data) {
      if (!context.mounted || data is! List) return;
      Provider.of<LobbyProvider>(context, listen: false)
          .setRooms(List<dynamic>.from(data));
    }

    _on('roomsList', handler);
    _on('rooms:list', handler); // olası alternatif event
  }

  void createRoomSuccessListener(BuildContext context) {
    _on('createRoomSuccess', (room) {
      if (!context.mounted || room is! Map) return;

      final map = Map<String, dynamic>.from(room);
      Provider.of<RoomDataProvider>(context, listen: false)
          .updateRoomData(map);

      final level = (map['level'] ?? map['mode'] ?? '').toString();
      final id = _roomIdOf(map);
      if (level == 'hard' && id.isNotEmpty) {
        startHardModeShuffle(id, List<String>.filled(9, ''));
      }
      Navigator.pushReplacementNamed(context, GameScreen.routeName);
    });
  }

  void joinRoomSuccessListener(BuildContext context) {
    _on('joinRoomSuccess', (room) {
      if (!context.mounted || room is! Map) return;

      final map = Map<String, dynamic>.from(room);
      Provider.of<RoomDataProvider>(context, listen: false)
          .updateRoomData(map);

      final level = (map['level'] ?? map['mode'] ?? '').toString();
      final id = _roomIdOf(map);
      if (level == 'hard' && id.isNotEmpty) {
        startHardModeShuffle(id, List<String>.filled(9, ''));
      }
      Navigator.pushReplacementNamed(context, GameScreen.routeName);
    });
  }

  void errorOccuredListener(BuildContext context) {
    // Sunucu bazen typo ile gönderebiliyor: errorOccurred / errorOccured
    for (final ev in const ['errorOccurred', 'errorOccured']) {
      _on(ev, (data) {
        if (!context.mounted) return;
        showSnackBar(context, data?.toString() ?? 'Bilinmeyen hata');
      });
    }
  }

  void updatePlayersStateListener(BuildContext context) {
    void handler(players) {
      if (!context.mounted || players is! List) return;
      final list = players
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);

      final rdp = Provider.of<RoomDataProvider>(context, listen: false);
      if (list.isNotEmpty) rdp.updatePlayer1(list[0]);
      if (list.length > 1) rdp.updatePlayer2(list[1]);
    }

    _on('updatePlayers', handler);
    _on('updatePlayersState', handler);
  }
void updateRoomListener(BuildContext context) {
  socketClient.off('updateRoom');
  socketClient.on('updateRoom', (room) {
    if (!context.mounted || room is! Map) return;

    final map = Map<String, dynamic>.from(room);

    // --- NORMALİZE: oyuncu sayısından isJoin çıkarımı ---
    final playersLen = (map['players'] is List) ? (map['players'] as List).length : 0;
    final occ = (map['occupancy'] is int)
        ? map['occupancy'] as int
        : int.tryParse('${map['occupancy']}') ?? 2;

    map['isJoin'] = playersLen < occ;
    // debug:
    // debugPrint('updateRoom -> players=$playersLen occ=$occ isJoin=${map['isJoin']}');

    Provider.of<RoomDataProvider>(context, listen: false).updateRoomData(map);
  });
}

void gameReadyListener(BuildContext context) {
  socketClient.off('gameReady');
  socketClient.on('gameReady', (room) {
    if (!context.mounted || room is! Map) return;

    final map = Map<String, dynamic>.from(room);

    // --- NORMALİZE (aynısı) ---
    final playersLen = (map['players'] is List) ? (map['players'] as List).length : 0;
    final occ = (map['occupancy'] is int)
        ? map['occupancy'] as int
        : int.tryParse('${map['occupancy']}') ?? 2;
    map['isJoin'] = playersLen < occ;

    Provider.of<RoomDataProvider>(context, listen: false).updateRoomData(map);
  });
}


  void tappedListener(BuildContext context) {
    _on('tapped', (data) {
      if (!context.mounted || data is! Map) return;

      final map = Map<String, dynamic>.from(data);
      final rdp = Provider.of<RoomDataProvider>(context, listen: false);

      final int index =
          (map['index'] is int) ? map['index'] as int : -1;
      final String choice = (map['choice'] ?? '').toString();
      if (index >= 0 && index < 9 && choice.isNotEmpty) {
        rdp.updateDisplayElements(index, choice);
      }

      final boardRaw = map['board'];
      if (boardRaw is List) {
        final board =
            boardRaw.map((e) => e.toString()).toList(growable: false);
        try {
          (rdp as dynamic).setBoard(board);
        } catch (_) {}
      }

      final roomMap =
          (map['room'] is Map) ? Map<String, dynamic>.from(map['room']) : null;
      if (roomMap != null) rdp.updateRoomData(roomMap);

      GameMethods().checkWinner(context, socket);
    });
  }

  void pointIncreaseListener(BuildContext context) {
    _on('pointIncrease', (playerData) {
      if (!context.mounted) return;
      if (playerData is Map) {
        Provider.of<RoomDataProvider>(context, listen: false)
            .applyPointIncrease(Map<String, dynamic>.from(playerData));
      }
      showSnackBar(context, 'Puan güncellendi.');
    });
  }

  void scoreUpdatedListener(BuildContext context) {
    _on('scoreUpdated', (payload) {
      if (!context.mounted || payload is! Map) return;
      Provider.of<RoomDataProvider>(context, listen: false)
          .applyScoreUpdated(Map<String, dynamic>.from(payload));
    });
  }

  void endGameListener(BuildContext context) {
    _on('endGame', (playerData) {
      if (!context.mounted) return;
      final winner =
          (playerData is Map ? playerData['nickname'] : null)?.toString() ??
              'Kazanan';
      showSnackBar(context, '$winner oyunu kazandı!');
      Navigator.popUntil(context, (route) => route.isFirst);
    });
  }

  void timeoutGameListener(BuildContext context) {
    _on('timeoutGame', (_) {
      if (!context.mounted) return;
      showSnackBar(context, 'Süre doldu! Ana menüye dönülüyor.');
      Navigator.popUntil(context, (route) => route.isFirst);
    });
  }

  void startNextRoundListener(
    BuildContext context, {
    VoidCallback? onRoundStart,
  }) {
    _on('startNextRound', (room) {
      if (!context.mounted) return;
      final rdp = Provider.of<RoomDataProvider>(context, listen: false);

      try {
        (rdp as dynamic).resetBoard();
        (rdp as dynamic).setFilledBoxesTo0();
        (rdp as dynamic).setBoardActive(true);
      } catch (_) {}

      if (room is Map) {
        final roomMap = Map<String, dynamic>.from(room);
        rdp.updateRoomData(roomMap);

        final level = (roomMap['level'] ?? roomMap['mode'] ?? '').toString();
        final id = _roomIdOf(roomMap);
        if (level == 'hard' && id.isNotEmpty) {
          startHardModeShuffle(id, List<String>.filled(9, ''));
        }
      }

      onRoundStart?.call();
    });
  }

  void shuffleBoardListener(BuildContext context) {
    _on('shuffleBoard', (data) {
      if (!context.mounted || data is! Map) return;

      final boardList = (data['board'] is List)
          ? List<String>.from(data['board'] as List)
          : null;
      if (boardList != null) {
        try {
          Provider.of<RoomDataProvider>(context, listen: false)
              .setBoard(boardList);
        } catch (_) {}
      }

      GameMethods().checkWinner(context, socket);
    });
  }
}

// opsiyonel debug
void showDebugPrint(String msg) {
  // debugPrint(msg);
}
