import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mp_tictactoe/provider/room_data_provider.dart';
import 'package:mp_tictactoe/resources/socket_methods.dart';
import 'package:mp_tictactoe/views/scoreboard.dart';
import 'package:mp_tictactoe/views/tictactoe_board.dart';
import 'package:mp_tictactoe/views/waiting_lobby.dart';

class GameScreen extends StatefulWidget {
  static const String routeName = '/game';
  const GameScreen({Key? key}) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final SocketMethods _socket = SocketMethods();

  Timer? _roundTimer;
  int _timeLeft = 30;
  bool _hardShuffleStarted = false;

  // Play-again el sıkışması
  bool _iAmReadyForNext = false;
  bool _waitingNextRound = false;

  // Oyun başlarken timer/shuffle yalnızca bir kez kurulsun
  bool _bootstrappedThisRound = false;

  @override
  void initState() {
    super.initState();
    _wireSocketListeners();
  }

  void _wireSocketListeners() {
    // Sunucudan gelen tüm güncellemeler
    _socket.scoreUpdatedListener(context);
    _socket.updateRoomListener(context);
    _socket.updatePlayersStateListener(context);
    _socket.pointIncreaseListener(context);
    _socket.endGameListener(context);
    _socket.timeoutGameListener(context);
    _socket.shuffleBoardListener(context);

    // Odaya girildi/oluşturuldu -> roomData güncellenir, ekrana geçiş yapılır
    _socket.createRoomSuccessListener(context);
    _socket.joinRoomSuccessListener(context);

    // 2 oyuncu hazır olduğunda (beklemeden çıkış sinyali)
    _socket.gameReadyListener(context);

    // Yeni raund başlatıldı sinyali
    _socket.startNextRoundListener(
      context,
      onRoundStart: () {
        if (!mounted) return;
        setState(() {
          _iAmReadyForNext = false;
          _waitingNextRound = false;
          _bootstrappedThisRound = false; // yeni raund; yeniden kur
        });
        _onRoundStart();
      },
    );
  }

  // Yeni raund başlarken modlara göre kurulum
  void _onRoundStart() {
    final rdp = Provider.of<RoomDataProvider>(context, listen: false);
    rdp.setBoardActive(true);

    final level = (rdp.roomData['level']?.toString() ?? 'easy');

    if (level == 'medium') {
      _startTimer();
      _stopHardShuffle(rdp);
    } else if (level == 'hard') {
      _roundTimer?.cancel();
      _startHardShuffle(rdp);
    } else {
      // easy
      _roundTimer?.cancel();
      _stopHardShuffle(rdp);
    }
  }

  void _startTimer() {
    _roundTimer?.cancel();
    setState(() => _timeLeft = 30);
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _roundTimer?.cancel();
        _onRoundEnd();
      }
    });
  }

  void _onRoundEnd() {
    final rdp = Provider.of<RoomDataProvider>(context, listen: false);
    if ((rdp.roomData['level']?.toString() ?? 'easy') == 'hard') {
      _stopHardShuffle(rdp);
    }
    _roundTimer?.cancel();
  }

  void _startHardShuffle(RoomDataProvider rdp) {
    if (_hardShuffleStarted) return;
    final roomId = (rdp.roomData['_id']?.toString() ?? '');
    if (roomId.isEmpty) return;

    _hardShuffleStarted = true;
    final board = List<String>.from(rdp.displayElements);
    _socket.startHardModeShuffle(roomId, board);
  }

  void _stopHardShuffle(RoomDataProvider rdp) {
    if (!_hardShuffleStarted) return;
    final roomId = (rdp.roomData['_id']?.toString() ?? '');
    if (roomId.isNotEmpty) {
      _socket.stopHardModeShuffle(roomId);
    }
    _hardShuffleStarted = false;
  }

  void _readyForNextRound(RoomDataProvider rdp) {
    final roomId = (rdp.roomData['_id']?.toString() ?? '');
    if (roomId.isEmpty) return;

    _socket.readyForNextRound(roomId);
    setState(() {
      _iAmReadyForNext = true;
      _waitingNextRound = true;
    });
  }

  Future<void> _emitLeaveIfPossible() async {
    try {
      final rdp = Provider.of<RoomDataProvider>(context, listen: false);
      final roomId = (rdp.roomData['_id'] ?? '').toString();
      if (roomId.isNotEmpty) {
        _socket.leaveRoom(roomId);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _roundTimer?.cancel();
    try {
      final rdp = Provider.of<RoomDataProvider>(context, listen: false);
      if ((rdp.roomData['level']?.toString() ?? 'easy') == 'hard') {
        _stopHardShuffle(rdp);
      }
    } catch (_) {}
    // Odadan ayrıldığını bildir (disconnect’i beklemeden)
    _emitLeaveIfPossible();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rdp = Provider.of<RoomDataProvider>(context);

    // Beklemede mi? (hem isJoin hem de oyuncu sayısı ile güvence)
    final players = (rdp.roomData['players'] is List)
        ? (rdp.roomData['players'] as List)
        : const <dynamic>[];
    final occ = (rdp.roomData['occupancy'] is int)
        ? rdp.roomData['occupancy'] as int
        : int.tryParse('${rdp.roomData['occupancy']}') ?? 2;
    final waiting = (rdp.roomData['isJoin'] == true) || (players.length < occ);
    final started = !waiting;

    // Oyun başladıysa timer/shuffle kurulumunu bir kere tetikle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!started) return;
      if (_bootstrappedThisRound) return;

      _bootstrappedThisRound = true;
      _onRoundStart();
    });

    // Sıradaki oyuncu (güvenli)
    String? turnNick;
    final turn = rdp.roomData['turn'];
    if (turn is Map && turn['nickname'] is String) {
      final n = (turn['nickname'] as String).trim();
      if (n.isNotEmpty) turnNick = n;
    }

    final isMedium = (rdp.roomData['level']?.toString() ?? 'easy') == 'medium';

    final Widget content = waiting
        ? const WaitingLobby()
        : Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const Scoreboard(),

              // Medium mod sayaç
              if (isMedium)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Kalan Süre: $_timeLeft sn',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              // Sıra bilgisi
              if (turnNick != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6.0, bottom: 2.0),
                  child: Text(
                    "$turnNick'İN SIRASI",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              // Tahta
              Expanded(
                child: AbsorbPointer(
                  absorbing: !rdp.isBoardActive,
                  child: const TicTacToeBoard(),
                ),
              ),

              // Tekrar Oyna
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _iAmReadyForNext ? null : () => _readyForNextRound(rdp),
                        child: Text(
                          _iAmReadyForNext
                              ? 'Hazır (diğer oyuncu bekleniyor...)'
                              : 'Tekrar Oyna',
                        ),
                      ),
                    ),
                    if (_waitingNextRound)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Diğer oyuncunun “Tekrar Oyna”ya basması bekleniyor…',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );

    return WillPopScope(
      onWillPop: () async {
        await _emitLeaveIfPossible();
        return true;
      },
      child: Scaffold(
        body: SafeArea(child: content),
      ),
    );
  }
}
