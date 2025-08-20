import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mp_tictactoe/provider/lobby_provider.dart';
import 'package:mp_tictactoe/resources/socket_methods.dart';
import 'package:mp_tictactoe/resources/socket_client.dart'; // auth ile bağlanmak için

class RoomsScreen extends StatefulWidget {
  static const routeName = '/rooms';
  const RoomsScreen({Key? key}) : super(key: key);

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  final _sockets = SocketMethods();
  
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // Bağlı değilse bağlan:
    if (!SocketClient().socket.connected) {
      await SocketClient().connectFromPrefs();
    }

    _sockets.roomsListListener(context);
    _sockets.joinRoomSuccessListener(context);
    _sockets.errorOccuredListener(context);
    _sockets.updatePlayersStateListener(context);
    _sockets.updateRoomListener(context);

    _sockets.requestRooms();
  });
}



  @override
  void dispose() {
    // Event isimleri server’da farklı olabilir; güvenli tarafta kalalım
    _sockets.socketClient
      ..off('roomsList')
      ..off('rooms:list')
      ..off('joinRoomSuccess')
      ..off('errorOccurred')
      ..off('errorOccured')
      ..off('updatePlayers')
      ..off('updatePlayersState')
      ..off('updateRoom')
      ..off('roomUpdated');
    super.dispose();
  }

  // Sunucudan gelen "oda" nesnesini UI’nin beklediği standarda çevirir
  Map<String, dynamic> _normalizeRoom(Map raw) {
    final id = (raw['id'] ?? raw['_id'])?.toString();
    final players = (raw['players'] is List) ? (raw['players'] as List) : const [];
    final playersCount =
        (raw['playersCount'] is int) ? raw['playersCount'] as int : players.length;

    final occupancy = (raw['maxPlayers'] ?? raw['occupancy'] ?? 2) as int; // toplam kapasite (genelde 2)

    final currentRound = (raw['currentRound'] is int) ? raw['currentRound'] as int : 1;
    final maxRounds = (raw['maxRounds'] is int) ? raw['maxRounds'] as int : 1;

    final inGame = (raw['inGame'] as bool?) ??
        // bazı server’larda isJoin=false => oyunda
        ((raw['isJoin'] is bool) ? !(raw['isJoin'] as bool) : false);

    final hasPassword = () {
      final p = raw['password'];
      if (p == null) return false;
      if (p is bool) return p;
      final s = p.toString().trim();
      return s.isNotEmpty;
    }();

    final level = (raw['level'] ?? raw['mode'] ?? 'easy').toString();
    final name = (raw['name'] ?? raw['roomName'] ?? '').toString().trim();

    // joinable akıl yürütmesi: alan yoksa players < occupancy ise join edilebilir say
    final canJoin = (raw['isJoin'] as bool?) ?? (!inGame && playersCount < occupancy);

    return {
      'id': id,
      'name': name,
      'playersCount': playersCount,
      'occupancy': occupancy,
      'currentRound': currentRound,
      'maxRounds': maxRounds,
      'inGame': inGame,
      'isJoin': canJoin,
      'locked': hasPassword,
      'level': level,
    };
  }

  String _shortId(Object? id) {
    final s = id?.toString() ?? '';
    if (s.isEmpty) return '------';
    return s.length >= 6 ? s.substring(0, 6) : s.padRight(6, '_');
  }

  @override
  Widget build(BuildContext context) {
    // Provider’dan ham liste (dynamic olabilir)
    final rawRooms = context.watch<LobbyProvider>().rooms ?? [];

    // normalize + filtre
    final rooms = rawRooms
        .whereType<Map>() // sadece Map olanları al
        .map(_normalizeRoom)
        .where((r) => (r['isJoin'] == true) || (r['inGame'] == true))
        .toList();

    final size = MediaQuery.of(context).size;

    final cross = size.width >= 1100
        ? 5
        : size.width >= 900
            ? 4
            : size.width >= 650
                ? 3
                : 2;

    final aspect = size.width < 420 ? 0.72 : (size.width < 900 ? 0.85 : 0.95);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rooms'),
        actions: [
          IconButton(
            onPressed: _sockets.requestRooms,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: rooms.isEmpty
            ? RefreshIndicator(
                onRefresh: () async {
                  _sockets.requestRooms();
                  await Future.delayed(const Duration(milliseconds: 400));
                },
                child: ListView(
                  children: const [
                    SizedBox(height: 160),
                    Center(child: Text('Aktif oda yok. Aşağı çekerek yenileyebilirsin.')),
                    SizedBox(height: 12),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  _sockets.requestRooms();
                  await Future.delayed(const Duration(milliseconds: 400));
                },
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cross,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: aspect,
                  ),
                  itemCount: rooms.length,
                  itemBuilder: (context, i) {
                    final r = rooms[i];
                    final roomId       = (r['id'] ?? '').toString();
                    final canJoin      = (r['isJoin'] as bool?) ?? false;
                    final locked       = (r['locked'] as bool?) ?? false;
                    final playersCount = (r['playersCount'] as int?) ?? 0;
                    final occupancy    = (r['occupancy'] as int?) ?? 2;
                    final level        = (r['level'] as String?) ?? 'easy';
                    final roundText    = 'Round ${(r['currentRound'] ?? 1)}/${(r['maxRounds'] ?? 1)}';
                    final idShort      = _shortId(r['id']);

                    final customName   = (r['name'] as String?)?.trim() ?? '';
                    final titleText    = customName.isNotEmpty ? customName : 'Room $idShort';

                    return _RoomCard(
                      title: titleText,
                      level: level,
                      playersText: '$playersCount/$occupancy players',
                      roundText: roundText,
                      canJoin: canJoin,
                      locked: locked,
                      onJoin: () async {
                        if (!canJoin) return;

                        if (locked) {
                          // Sadece şifre iste
                          final pwd = await _askPasswordOnly(context);
                          if (pwd == null || pwd.isEmpty) return;
                          _sockets.joinRoomById(roomId: roomId, password: pwd);
                        } else {
                          // Şifresiz oda: direkt katıl (nickname sormuyoruz)
                          _sockets.joinRoomById(roomId: roomId);
                        }
                      },
                    );
                  },
                ),
              ),
      ),
    );
  }

  /// Sadece şifre isteyen dialog
  Future<String?> _askPasswordOnly(BuildContext ctx) async {
    final passC = TextEditingController();
    return showDialog<String>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Room password'),
        content: TextField(
          controller: passC,
          decoration: const InputDecoration(labelText: 'Password'),
          obscureText: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, passC.text.trim()),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final String title;
  final String level;
  final String playersText;
  final String roundText;
  final bool canJoin;
  final bool locked;
  final VoidCallback onJoin;

  const _RoomCard({
    required this.title,
    required this.level,
    required this.playersText,
    required this.roundText,
    required this.canJoin,
    required this.locked,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = canJoin ? Colors.greenAccent : Colors.orangeAccent;

    return InkWell(
      onTap: canJoin ? onJoin : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1C1B29), Color(0xFF0F0E17)],
          ),
          border: Border.all(color: Colors.white12),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 6))],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                if (locked)
                  const Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Icon(Icons.lock, size: 16),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: statusColor.withOpacity(0.7)),
                  ),
                  child: Text(
                    canJoin ? 'JOINABLE' : 'IN GAME',
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Info chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(icon: Icons.videogame_asset, text: 'Level: $level'),
                _chip(icon: Icons.group, text: playersText),
                _chip(icon: Icons.repeat, text: roundText),
              ],
            ),
            const Spacer(),
            // Join button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: canJoin ? onJoin : null,
                icon: Icon(locked ? Icons.lock_open : Icons.login, size: 18),
                label: const Text('Join'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: canJoin ? Colors.blueAccent : Colors.grey,
                  disabledBackgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Text(text),
      ]),
    );
  }
}
