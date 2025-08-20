// Oyuncu bilgilerini tutmak için bir sınıf
class Player {
  String nickname;
  String socketID;
  int points;
  String playerType;

  Player({
    required this.nickname,
    required this.socketID,
    required this.points,
    required this.playerType,
  });

  Map<String, dynamic> toMap() => {
        'nickname': nickname,
        'socketID': socketID,
        'points': points,
        'playerType': playerType,
      };

  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      nickname: (map['nickname'] as String?) ?? '',
      socketID: (map['socketID'] as String?) ?? '',
      points: (map['points'] as num?)?.toInt() ?? 0, // güvenli int dönüşümü
      playerType: (map['playerType'] as String?) ?? 'X',
    );
  }

  // Tipler tutarlı: points -> int?
  Player copyWith({
    String? nickname,
    String? socketID,
    int? points,
    String? playerType,
  }) {
    return Player(
      nickname: nickname ?? this.nickname,
      socketID: socketID ?? this.socketID,
      points: points ?? this.points,
      playerType: playerType ?? this.playerType,
    );
  }
}
