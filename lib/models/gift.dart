class Gift {
  final int? id;
  final int guestId;
  final double amount;
  final bool isReceived; // true = 收礼, false = 送礼
  final String eventType;
  final DateTime date;
  final String? note;

  Gift({
    this.id,
    required this.guestId,
    required this.amount,
    required this.isReceived,
    required this.eventType,
    required this.date,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'guestId': guestId,
      'amount': amount,
      'isReceived': isReceived ? 1 : 0,
      'eventType': eventType,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory Gift.fromMap(Map<String, dynamic> map) {
    return Gift(
      id: map['id'] as int?,
      guestId: map['guestId'] as int,
      amount: (map['amount'] as num).toDouble(),
      isReceived: map['isReceived'] == 1,
      eventType: map['eventType'] as String,
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
    );
  }

  Gift copyWith({
    int? id,
    int? guestId,
    double? amount,
    bool? isReceived,
    String? eventType,
    DateTime? date,
    String? note,
  }) {
    return Gift(
      id: id ?? this.id,
      guestId: guestId ?? this.guestId,
      amount: amount ?? this.amount,
      isReceived: isReceived ?? this.isReceived,
      eventType: eventType ?? this.eventType,
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }
}

// 事件类型常量
class EventTypes {
  static const String wedding = '婚礼';
  static const String babyShower = '满月';
  static const String housewarming = '乔迁';
  static const String birthday = '生日';
  static const String funeral = '丧事';
  static const String newYear = '过年';
  static const String other = '其他';

  static List<String> get all => [
    wedding,
    babyShower,
    housewarming,
    birthday,
    funeral,
    newYear,
    other,
  ];
}
