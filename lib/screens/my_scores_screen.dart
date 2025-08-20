// lib/screens/my_scores_screen.dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

/// --- Basit veri modeli ---
class MatchItem {
  final String roomId;
  final String roomName;
  final String level;
  final String opponentKey;      // öncelik: opponentEmail, yoksa nickname
  final String opponentDisplay;  // UI'da göstereceğimiz metin
  final String result;           // "win" | "loss" | "draw"
  final DateTime createdAt;

  MatchItem({
    required this.roomId,
    required this.roomName,
    required this.level,
    required this.opponentKey,
    required this.opponentDisplay,
    required this.result,
    required this.createdAt,
  });

  factory MatchItem.fromMap(Map<String, dynamic> m) {
    final roomId   = (m['room'] ?? '').toString();
    final roomName = (m['roomName'] ?? '').toString();
    final level    = (m['level'] ?? '').toString();
    final oppEmail = (m['opponentEmail'] ?? '').toString();
    final oppNick  = (m['opponentNickname'] ?? '').toString();
    final result   = (m['result'] ?? '').toString(); // win/loss/draw

    // ISO-UTC bekleniyor -> local'e çevir
    final created = DateTime.tryParse(m['createdAt']?.toString() ?? '')?.toLocal() ?? DateTime.now();

    final oppKey     = oppEmail.isNotEmpty ? oppEmail : (oppNick.isNotEmpty ? oppNick : 'unknown');
    final oppDisplay = oppNick.isNotEmpty ? oppNick : (oppEmail.isNotEmpty ? oppEmail : 'Bilinmeyen');

    return MatchItem(
      roomId: roomId,
      roomName: roomName,
      level: level,
      opponentKey: oppKey,
      opponentDisplay: oppDisplay,
      result: result,
      createdAt: created,
    );
  }
}

class MatchAgg {
  final String groupKey; // roomId|opponentKey (roomId yoksa roomName)
  final String roomName;
  final String level;
  final String opponent;
  int wins = 0;
  int losses = 0;
  int draws = 0;
  DateTime lastPlayed;

  MatchAgg({
    required this.groupKey,
    required this.roomName,
    required this.level,
    required this.opponent,
    required this.lastPlayed,
  });

  String overall() {
    if (wins > losses) return 'win';
    if (losses > wins) return 'loss';
    return 'draw';
  }
}

class MyScoresScreen extends StatefulWidget {
  final String email; // giriş yapan kullanıcının e-postası
  const MyScoresScreen({Key? key, required this.email}) : super(key: key);

  @override
  State<MyScoresScreen> createState() => _MyScoresScreenState();
}

class _MyScoresScreenState extends State<MyScoresScreen> {
  late Future<List<MatchAgg>> _future;

  String get _base {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  Future<List<MatchAgg>> _fetchGrouped() async {
    final uri = Uri.parse('$_base/users/${Uri.encodeComponent(widget.email)}/matches?limit=500');
    final resp = await http.get(uri, headers: {'Accept': 'application/json'});
    if (resp.statusCode != 200) {
      throw Exception('Sunucu hatası: ${resp.statusCode}');
    }

    final decoded = json.decode(resp.body);
    if (decoded is! Map) return const [];

    final itemsRaw = (decoded['items'] as List?) ?? const [];
    final items = itemsRaw
        .whereType<Map>()
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .map(MatchItem.fromMap)
        .toList();

    // --- GRUPLAMA: roomId (varsa) + opponentKey ---
    final Map<String, MatchAgg> groups = {};
    for (final it in items) {
      final roomKey = it.roomId.isNotEmpty ? it.roomId : it.roomName;
      final gkey = '$roomKey|${it.opponentKey}';

      final agg = groups[gkey] ??
          MatchAgg(
            groupKey: gkey,
            roomName: it.roomName,
            level: it.level,
            opponent: it.opponentDisplay,
            lastPlayed: it.createdAt,
          );

      // 🔒 Tek kaynak: sadece 'result' alanını say.
      if (it.result == 'win') {
        agg.wins += 1;
      } else if (it.result == 'loss') {
        agg.losses += 1;
      } else {
        agg.draws += 1;
      }

      if (it.createdAt.isAfter(agg.lastPlayed)) {
        agg.lastPlayed = it.createdAt;
      }

      groups[gkey] = agg;
    }

    final list = groups.values.toList();
    list.sort((a, b) => b.lastPlayed.compareTo(a.lastPlayed)); // En son oynanan en üstte
    return list;
  }

  @override
  void initState() {
    super.initState();
    _future = _fetchGrouped();
  }

  String _formatDate(DateTime dt) {
    // dt zaten local; yine de emniyet:
    final local = dt.toLocal();
    return DateFormat('dd.MM.yyyy  HH:mm').format(local);
  }

  Color _resultColor(String r) {
    switch (r) {
      case 'win':
        return Colors.green;
      case 'loss':
        return Colors.red;
      default:
        return Colors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseText = Theme.of(context).textTheme.bodyMedium;

    return Scaffold(
      appBar: AppBar(title: const Text('Skorlarım')),
      body: FutureBuilder<List<MatchAgg>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Hata: ${snap.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => setState(() => _future = _fetchGrouped()),
                    child: const Text('Yenile'),
                  ),
                ],
              ),
            );
          }
          final groups = snap.data ?? const [];
          if (groups.isEmpty) {
            return const Center(child: Text('Henüz bir kayıt yok.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            itemCount: groups.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final g = groups[i];
              final result = g.overall();
              final color = _resultColor(result);

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Oda adı (level) + sağda toplam SONUÇ rozeti
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            g.level.isEmpty ? g.roomName : '${g.roomName} (${g.level})',
                            style: baseText?.copyWith(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(.15),
                            border: Border.all(color: color.withOpacity(.5)),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            result.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: color,
                              letterSpacing: .5,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // 🔢 Win / Loss — yalnızca gruptan (tek kaynak)
                    Row(
                      children: [
                        Text('aldığı win: ${g.wins}', style: baseText),
                        const SizedBox(width: 12),
                        Text('aldığı loss: ${g.losses}', style: baseText),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Rakip
                    Text('rakip: ${g.opponent}', style: baseText),

                    const SizedBox(height: 4),

                    // Son oynanma (local format)
                    Text(
                      _formatDate(g.lastPlayed),
                      style: baseText?.copyWith(color: baseText?.color?.withOpacity(.8)),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
