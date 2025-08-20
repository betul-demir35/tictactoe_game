import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'admin_provider.dart';

class AdminScores extends StatelessWidget {
  const AdminScores({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AdminProvider>();

    return Column(
      children: [
        // Üst bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Text('Scores (last 100)'),
              const Spacer(),
              IconButton(
                onPressed: () => p.loadScores(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        // Liste alanı
        Expanded(
          child: p.loadingScores && p.scores.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () async => p.loadScores(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: p.scores.length,
                    itemBuilder: (context, i) {
                      final s = p.scores[i] as Map<String, dynamic>;

                      // JSON’dan değerleri çek
                      final players =
                          List<Map<String, dynamic>>.from(s['players'] ?? []);
                      final totals =
                          Map<String, dynamic>.from(s['totals'] ?? {});
                     final rounds = (s['history'] as List?)?.length ?? 0;
                      final room = s['room'];
                      final roomName = room is Map ? (room['name'] ?? room['_id']) : room ?? 'Unknown';
                      return Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Oda adı
                              Text(
                                    "ODA: $roomName",
                                    style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                      ),
                                    ),
                              const SizedBox(height: 6),
                              // Round sayısı
                              Text("Round Sayısı: $rounds"),
                              const Divider(),
                              // Oyuncular
                              ...players.map((p) {
                                final name = p['nickname'];
                                final type = p['playerType']; // X ya da O
                                final score = totals[type] ?? 0;
                                return Text(
                                  "$name : $score",
                                  style: const TextStyle(fontSize: 14),
                                );
                              }),
                              const SizedBox(height: 6),
                              // Sil butonu
                              Align(
                                alignment: Alignment.centerRight,
                                child: IconButton(
                                  tooltip: 'Delete score',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    final ok = await _confirm(
                                        context, "Delete score for room $room?");
                                    if (ok) {
                                      await context
                                          .read<AdminProvider>()
                                          .removeScore(room.toString());
                                    }
                                  },
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // Onay diyaloğu
  Future<bool> _confirm(BuildContext context, String msg) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return r ?? false;
  }
}
