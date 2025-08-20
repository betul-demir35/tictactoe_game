import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'admin_provider.dart';
import 'admin_room_detail.dart';

class AdminRooms extends StatefulWidget {
   const AdminRooms({Key? key}) : super(key: key);
  @override
  State<AdminRooms> createState() => _AdminRoomsState();
}

class _AdminRoomsState extends State<AdminRooms> {
  final _q = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AdminProvider>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _q,
                  decoration: InputDecoration(
                    hintText: 'Search by name/level…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _q.text.isEmpty
                        ? null
                        : IconButton(icon: const Icon(Icons.clear), onPressed: () { _q.clear(); setState(() {}); p.loadRooms(p: 1, q: ''); }),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onSubmitted: (v) => p.loadRooms(p: 1, q: v),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(onPressed: () => p.loadRooms(), icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
        Expanded(
          child: p.loadingRooms && p.rooms.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () async => p.loadRooms(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Name')),
                            DataColumn(label: Text('Level')),
                            DataColumn(label: Text('Players')),
                            DataColumn(label: Text('Round')),
                            DataColumn(label: Text('Locked')),
                            DataColumn(label: Text('CreatedAt')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: p.rooms.map((r) {
                            final name = (r['name'] as String?)?.trim();
                            final id = r['_id']?.toString() ?? r['id']?.toString() ?? '';
                            final players = List.from(r['players'] ?? []);
                            final locked = (r['locked'] == true) || ((r['password'] ?? '').toString().isNotEmpty);

                            return DataRow(cells: [
                              DataCell(Text(name?.isNotEmpty == true ? name! : 'Room ${id.substring(0,6)}')),
                              DataCell(Text('${r['level']}')),
                              DataCell(Text('${players.length}/${r['occupancy']}')),
                              DataCell(Text(' ${r['currentRound']}/${r['maxRounds']}')),
                              DataCell(locked ? const Icon(Icons.lock) : const SizedBox()),
                              DataCell(Text('${r['createdAt']}')),
                              DataCell(Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'View',
                                    icon: const Icon(Icons.visibility_outlined),
                                    onPressed: id.isEmpty ? null : () {
                                      Navigator.push(context, MaterialPageRoute(
                                        builder: (_) => AdminRoomDetail(roomId: id),
                                      ));
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Delete room',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: id.isEmpty ? null : () async {
                                      final ok = await _confirm(context, 'Delete this room?');
                                      if (ok) await context.read<AdminProvider>().removeRoom(id);
                                    },
                                  ),
                                ],
                              )),
                            ]);
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _pager(context, p),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _pager(BuildContext context, AdminProvider p) {
    final totalPages = (p.totalRooms / p.limit).ceil().clamp(1, 9999);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('Page ${p.page} / $totalPages'),
        IconButton(
          onPressed: (p.page > 1) ? () => p.loadRooms(p: p.page - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          onPressed: (p.page < totalPages) ? () => p.loadRooms(p: p.page + 1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Future<bool> _confirm(BuildContext context, String msg) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('OK')),
        ],
      ),
    );
    return r ?? false;
  }
}
