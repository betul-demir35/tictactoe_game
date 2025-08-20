import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../admin_api.dart';
import '../admin_provider.dart';
import '../admin_dashboard.dart';
import '../admin_rooms.dart';
import '../admin_scores.dart';
import '../admin_users.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({Key? key}) : super(key: key);

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminProvider(AdminApi())
        ..loadOverview()
        ..loadRooms()
        ..loadScores()
        ..loadUsers(), // ✅ loadBans() kaldırıldı
      child: Builder(
        builder: (context) {
          final pages = const [
            AdminDashboard(),
            AdminRooms(),
            AdminScores(),
            AdminUsers(),
          ];

          final titles = ['Dashboard', 'odalar', 'skorlar', 'users'];

          return Scaffold(
            appBar: AppBar(title: Text('Admin • ${titles[index]}')),
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: (v) => setState(() => index = v),
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                        icon: Icon(Icons.analytics_outlined),
                        label: Text('Dashboard')),
                    NavigationRailDestination(
                        icon: Icon(Icons.meeting_room_outlined),
                        label: Text('odalar')),
                    NavigationRailDestination(
                        icon: Icon(Icons.score_outlined),
                        label: Text('skorlar')),
                    NavigationRailDestination(
                        icon: Icon(Icons.people_outline),
                        label: Text('users')),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: pages[index]),
              ],
            ),
          );
        },
      ),
    );
  }
}