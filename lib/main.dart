import 'package:flutter/material.dart';

import 'package:mp_tictactoe/screens/create_room_screen.dart';
import 'package:mp_tictactoe/screens/game_screen.dart';
import 'package:mp_tictactoe/screens/join_room_screen.dart';
import 'package:mp_tictactoe/screens/main_menu_screen.dart';
import 'package:mp_tictactoe/screens/rooms_screen.dart';

import 'package:mp_tictactoe/utils/colors.dart';
import 'package:mp_tictactoe/admin/widgets/admin_shell.dart';
import 'package:mp_tictactoe/provider/room_data_provider.dart';
import 'package:mp_tictactoe/provider/lobby_provider.dart';

// ✅ Admin için eklenen importlar
import 'package:mp_tictactoe/admin/admin_provider.dart';
import 'package:mp_tictactoe/admin/admin_api.dart';

import 'package:provider/provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RoomDataProvider()),
        ChangeNotifierProvider(create: (_) => LobbyProvider()),

        // ✅ AdminProvider da eklendi
        ChangeNotifierProvider(create: (_) => AdminProvider(AdminApi())),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'TicTacToe',
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: bgColor,
        ),
        initialRoute: MainMenuScreen.routeName,
        routes: {
          MainMenuScreen.routeName: (_) => const MainMenuScreen(),
          JoinRoomScreen.routeName: (_) => const JoinRoomScreen(),
          CreateRoomScreen.routeName: (_) => const CreateRoomScreen(),
          GameScreen.routeName: (_) => const GameScreen(),
          RoomsScreen.routeName: (_) => const RoomsScreen(),

          // ✅ Admin paneli
          '/admin': (_) => const AdminShell(),
        },
      ),
    );
  }
}
