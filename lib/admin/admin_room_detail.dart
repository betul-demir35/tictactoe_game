import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'admin_provider.dart';
import 'package:intl/intl.dart'; // tarih formatlama için

class AdminRoomDetail extends StatefulWidget {
  const AdminRoomDetail({Key? key, required this.roomId}) : super(key: key);
  final String roomId;

  @override
  State<AdminRoomDetail> createState() => _AdminRoomDetailState();
}

class _AdminRoomDetailState extends State<AdminRoomDetail> {
@override
void initState() {
  super.initState();

  // Build bittikten sonra çağır
  WidgetsBinding.instance.addPostFrameCallback((_) {
    context.read<AdminProvider>().loadRoomDetail(widget.roomId);
  });
}


  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final r = provider.roomDetail;

    return Scaffold(
      appBar: AppBar(title: const Text('Room Detail')),
      body: provider.loadingRoomDetail && r == null
          ? const Center(child: CircularProgressIndicator())
          : r == null
              ? const Center(child: Text('Not found'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Oda bilgileri
                    _infoCard("Room Name", r['name'] ?? "(unnamed)"),
                    _infoCard("Level", "${r['level']}"),
                    _infoCard("Rounds", "${r['currentRound']}/${r['maxRounds']}"),

                    // Tarih / saat formatlama
                    _infoCard(
                      "Created At",
                      _formatDate(r['createdAt']),
                    ),

                    const SizedBox(height: 20),

                    // Kurucu
                    const Text("Owner",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (provider.owner != null)
                      _playerTile(provider.owner!, isOwner: true),

                    const SizedBox(height: 20),

                    // Katılımcılar
                    const Text("Participants",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Card(
                      child: Column(
                        children: provider.participants
                            .map((p) => _playerTile(p))
                            .toList(),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _infoCard(String title, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playerTile(Map<String, dynamic> p1, {bool isOwner = false}) {
    return ListTile(
      leading: CircleAvatar(
        child: Text((p1['playerType'] ?? '?').toString()),
      ),
      title: Text(
        (p1['nickname'] ?? '').toString(),
        style: TextStyle(fontWeight: isOwner ? FontWeight.bold : FontWeight.normal),
      ),
      subtitle: Text(
        "Score: ${p1['points'] ?? 0} | Type: ${p1['playerType'] ?? '-'}",
      ),
      trailing: isOwner
          ? const Text("(Owner)", style: TextStyle(color: Colors.green))
          : IconButton(
              icon: const Icon(Icons.person_remove_alt_1_outlined),
              tooltip: 'Kick',
              onPressed: () async {
                final ok = await _confirm(context, 'Kick ${p1['nickname']}?');
                if (ok) {
                  await context.read<AdminProvider>().kickFromRoom(
                        widget.roomId,
                        socketID: (p1['socketID'] ?? '').toString(),
                      );
                }
              },
            ),
    );
  }

  String _formatDate(dynamic isoDate) {
    if (isoDate == null) return "-";
    try {
      final dt = DateTime.parse(isoDate.toString());
      return DateFormat("dd/MM/yyyy HH:mm").format(dt);
    } catch (_) {
      return isoDate.toString();
    }
  }

  Future<bool> _confirm(BuildContext context, String msg) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('OK')),
        ],
      ),
    );
    return r ?? false;
  }
}
