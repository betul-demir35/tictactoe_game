import 'package:flutter/material.dart';
import 'admin_api.dart';

class AdminProvider extends ChangeNotifier {
  AdminProvider(this.api);
  final AdminApi api;

  // -------------------- OVERVIEW --------------------
  Map<String, dynamic>? overview;
  bool loadingOverview = false;

  Future<void> loadOverview() async {
    loadingOverview = true;
    notifyListeners();
    try {
      overview = await api.getOverview();
    } finally {
      loadingOverview = false;
      notifyListeners();
    }
  }

  // -------------------- ROOMS --------------------
  List<Map<String, dynamic>> rooms = [];
  int totalRooms = 0;
  int page = 1;
  int limit = 25;
  String query = '';
  bool loadingRooms = false;

  Future<void> loadRooms({int? p, String? q}) async {
    loadingRooms = true;
    notifyListeners();
    if (p != null) page = p;
    if (q != null) query = q;
    try {
      final res = await api.getRooms(page: page, limit: limit, q: query);
      rooms = List<Map<String, dynamic>>.from(res['items'] as List);
      totalRooms = (res['total'] as num?)?.toInt() ?? 0;
    } finally {
      loadingRooms = false;
      notifyListeners();
    }
  }

  Future<void> loadRoomDetail(String id) async {
    loadingRoomDetail = true;
    notifyListeners();
    try {
      roomDetail = await api.getRoom(id);
    } finally {
      loadingRoomDetail = false;
      notifyListeners();
    }
  }

  Future<void> removeRoom(String id) async {
    await api.deleteRoom(id);
    await loadRooms();
  }

  Future<void> kickFromRoom(String roomId,
      {String? socketID, String? nickname}) async {
    await api.kickPlayer(roomId, socketID: socketID, nickname: nickname);
    await loadRoomDetail(roomId);
  }

  // -------------------- ROOM DETAIL --------------------
  Map<String, dynamic>? roomDetail;
  bool loadingRoomDetail = false;

  // -------------------- SCORES --------------------
  List<dynamic> scores = [];
  bool loadingScores = false;

  Future<void> loadScores({String? roomId}) async {
    loadingScores = true;
    notifyListeners();
    try {
      scores = await api.getScores(roomId: roomId);
    } finally {
      loadingScores = false;
      notifyListeners();
    }
  }

  Future<void> removeScore(String roomId) async {
    await api.deleteScore(roomId);
    await loadScores();
  }

  // -------------------- BANS --------------------
  List<dynamic> bans = [];
  bool loadingBans = false;

  Future<void> loadBans() async {
    loadingBans = true;
    notifyListeners();
    try {
      bans = await api.getBans();
    } finally {
      loadingBans = false;
      notifyListeners();
    }
  }

  Future<void> addBan(String nickname, {String reason = ''}) async {
    await api.addBan(nickname, reason: reason);
    await loadBans();
  }

  Future<void> removeBan(String nickname) async {
    await api.removeBan(nickname);
    await loadBans();
  }

  // -------------------- USERS --------------------
  List<Map<String, dynamic>> users = [];
  int usersTotal = 0;
  int usersPage = 1;
  int usersLimit = 25;
  String usersQuery = '';
  bool loadingUsers = false;

Future<void> loadUsers({int? p, String? q}) async {
  loadingUsers = true;
  notifyListeners();

  if (p != null) usersPage = p;
  if (q != null) usersQuery = q;

  try {
    final res = await api.getUsers(
      page: usersPage,
      limit: usersLimit,
      q: usersQuery,
    );

    print('DEBUG USERS RESPONSE: $res'); // kontrol için

    // BURAYI DÜZELTTİK 👇
    users = List<Map<String, dynamic>>.from(res['users'] ?? []);
    usersTotal = (res['total'] as num?)?.toInt() ?? users.length;
  } finally {
    loadingUsers = false;
    notifyListeners();
  }
}


  Future<void> removeUser(String id) async {
    await api.deleteUser(id);
    // 🔑 Burada tekrar loadUsers çağırınca query & page korunur
    await loadUsers(p: usersPage, q: usersQuery);
  }
}

// -------------------- EXTRA HELPERS --------------------
extension RoomDetailHelpers on AdminProvider {
  Map<String, dynamic>? get owner {
    if (roomDetail == null) return null;
    final players =
        List<Map<String, dynamic>>.from(roomDetail?['players'] ?? []);
    if (players.isEmpty) return null;
    return players.first;
  }

  List<Map<String, dynamic>> get participants {
    if (roomDetail == null) return [];
    final players =
        List<Map<String, dynamic>>.from(roomDetail?['players'] ?? []);
    if (players.length <= 1) return [];
    return players.sublist(1);
  }
}
