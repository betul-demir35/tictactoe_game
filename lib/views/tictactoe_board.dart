import 'package:flutter/material.dart';
import 'package:mp_tictactoe/provider/room_data_provider.dart';
import 'package:mp_tictactoe/resources/socket_methods.dart';
import 'package:provider/provider.dart';

class TicTacToeBoard extends StatefulWidget {
  const TicTacToeBoard({Key? key}) : super(key: key);

  @override
  State<TicTacToeBoard> createState() => _TicTacToeBoardState();
}

class _TicTacToeBoardState extends State<TicTacToeBoard> {
  final SocketMethods _socketMethods = SocketMethods();

  @override
  void initState() {
    super.initState();
    _socketMethods.tappedListener(context);
  }

void tapped(int index, RoomDataProvider provider) {
  final turn = provider.roomData['turn'];
  final isMyTurn = (turn is Map && turn['socketID'] == _socketMethods.socketClient.id);

  if (isMyTurn &&
      provider.isBoardActive &&
      provider.displayElements[index] == '') {
    _socketMethods.tapGrid(
      index,
      provider.roomData['_id'],
      provider.displayElements,
    );
  }
}


  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    RoomDataProvider provider = Provider.of<RoomDataProvider>(context);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: size.height * 0.7,
        maxWidth: 500,
      ),
      child: AbsorbPointer(
        absorbing: !provider.isBoardActive ||
            provider.roomData['turn']['socketID'] != _socketMethods.socketClient.id,
        child: GridView.builder(
          itemCount: 9,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
          ),
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () => tapped(index, provider),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  color: Colors.transparent,
                ),
                child: Center(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      provider.displayElements[index],
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 80,
                        shadows: [
                          Shadow(
                            blurRadius: 30,
                            color: provider.displayElements[index] == 'O'
                                ? Colors.red
                                : Colors.blue,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
