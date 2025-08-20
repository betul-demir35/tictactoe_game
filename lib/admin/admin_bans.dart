import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'admin_provider.dart';

class AdminBans extends StatefulWidget {
   const AdminBans({Key? key}) : super(key: key);

  @override
  State<AdminBans> createState() => _AdminBansState();
}

class _AdminBansState extends State<AdminBans> {
  final nickC = TextEditingController();
  final reasonC = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AdminProvider>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              SizedBox(
                width: 240,
                child: TextField(
                  controller: nickC,
                  decoration: const InputDecoration(labelText: 'isim'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: reasonC,
                  decoration: const InputDecoration(labelText: 'sebep (opsiyonel)'),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  if (nickC.text.trim().isEmpty) return;
                  await context.read<AdminProvider>().addBan(nickC.text.trim(), reason: reasonC.text.trim());
                  nickC.clear(); reasonC.clear();
                },
                child: const Text('banla'),
              ),
              const Spacer(),
              IconButton(onPressed: () => p.loadBans(), icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
        Expanded(
          child: p.loadingBans && p.bans.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () async => p.loadBans(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: p.bans.length,
                    itemBuilder: (context, i) {
                      final b = p.bans[i] as Map<String, dynamic>;
                      return Card(
                        child: ListTile(
                          title: Text(b['nickname'] ?? ''),
                          subtitle: Text('Reason: ${b['reason'] ?? ''}\nCreated: ${b['createdAt']}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final ok = await _confirm(context, 'Unban ${b['nickname']}?');
                              if (ok) await context.read<AdminProvider>().removeBan((b['nickname']).toString());
                            },
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

  Future<bool> _confirm(BuildContext context, String msg) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('onayla'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('temizle')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('okito')),
        ],
      ),
    );
    return r ?? false;
  }
}
