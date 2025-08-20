import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'admin_provider.dart';

class AdminUsers extends StatefulWidget {
  const AdminUsers({Key? key}) : super(key: key);

  @override
  State<AdminUsers> createState() => _AdminUsersState();
}

class _AdminUsersState extends State<AdminUsers> {
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
                    hintText: 'Search by username/email…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _q.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _q.clear();
                              setState(() {});
                              p.loadUsers(p: 1, q: '');
                            },
                          ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onSubmitted: (v) => p.loadUsers(p: 1, q: v),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                  onPressed: () => p.loadUsers(),
                  icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
        Expanded(
          child: p.loadingUsers && p.users.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () async => p.loadUsers(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Username')),
                            DataColumn(label: Text('Email')),
                            DataColumn(label: Text('Verified')),
                            DataColumn(label: Text('CreatedAt')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: p.users.map<DataRow>((u) {
                            final id = (u['_id'] ?? u['id'] ?? '').toString();
                            return DataRow(
                              cells: [
                                DataCell(
                                    Text((u['username'] ?? '').toString())),
                                DataCell(Text((u['email'] ?? '').toString())),
                                DataCell(
                                  Icon(
                                    (u['isVerified'] == true)
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: (u['isVerified'] == true)
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                                DataCell(
                                    Text((u['createdAt'] ?? '').toString())),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Delete user',
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: id.isEmpty
                                            ? null
                                            : () async {
                                                final ok = await _confirm(
                                                    context,
                                                    'Delete this user?');
                                                if (ok) {
                                                  await context
                                                      .read<AdminProvider>()
                                                      .removeUser(id);
                                                }
                                              },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
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
    final totalPages =
        (p.usersTotal / p.usersLimit).ceil().clamp(1, 9999);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('Page ${p.usersPage} / $totalPages'),
        IconButton(
          onPressed: (p.usersPage > 1)
              ? () => p.loadUsers(p: p.usersPage - 1)
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          onPressed: (p.usersPage < totalPages)
              ? () => p.loadUsers(p: p.usersPage + 1)
              : null,
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
