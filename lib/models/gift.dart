class Gift {
  final int? id;
  final int guestId;
  final double amount;
  final bool isReceived; // true = 收礼, false = 送礼
  final String eventType;
  final int? eventBookId;
  final DateTime date;
  final String? note;
  
  // 还礼追踪字段
  final int? relatedRecordId;   // 关联记录ID（收礼-回礼对）
  final bool isReturned;        // 是否已还/已收（默认false）
  final DateTime? returnDueDate; // 建议还/收日期（收礼日期+180天）
  final int remindedCount;      // 已提醒次数（默认0，超过3次变灰）

  Gift({
    this.id,
    required this.guestId,
    required this.amount,
    required this.isReceived,
    required this.eventType,
    this.eventBookId,
    required this.date,
    this.note,
    this.relatedRecordId,
    this.isReturned = false,
    this.returnDueDate,
    this.remindedCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'guestId': guestId,
      'amount': amount,
      'isReceived': isReceived ? 1 : 0,
      'eventType': eventType,
      'eventBookId': eventBookId,
      'date': date.toIso8601String(),
      'note': note,
      'relatedRecordId': relatedRecordId,
      'isReturned': isReturned ? 1 : 0,
      'returnDueDate': returnDueDate?.toIso8601String(),
      'remindedCount': remindedCount,
    };
  }

  factory Gift.fromMap(Map<String, dynamic> map) {
    return Gift(
      id: map['id'] as int?,
      guestId: map['guestId'] as int,
      amount: (map['amount'] as num).toDouble(),
      isReceived: map['isReceived'] == 1,
      eventType: map['eventType'] as String,
      eventBookId: map['eventBookId'] as int?,
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
      relatedRecordId: map['relatedRecordId'] as int?,
      isReturned: map['isReturned'] == 1,
      returnDueDate: map['returnDueDate'] != null 
          ? DateTime.parse(map['returnDueDate'] as String) 
          : null,
      remindedCount: (map['remindedCount'] as int?) ?? 0,
    );
  }

  Gift copyWith({
    int? id,
    int? guestId,
    double? amount,
    bool? isReceived,
    String? eventType,
    int? eventBookId,
    DateTime? date,
    String? note,
    int? relatedRecordId,
    bool? isReturned,
    DateTime? returnDueDate,
    int? remindedCount,
  }) {
    return Gift(
      id: id ?? this.id,
      guestId: guestId ?? this.guestId,
      amount: amount ?? this.amount,
      isReceived: isReceived ?? this.isReceived,
      eventType: eventType ?? this.eventType,
      eventBookId: eventBookId ?? this.eventBookId,
      date: date ?? this.date,
      note: note ?? this.note,
      relatedRecordId: relatedRecordId ?? this.relatedRecordId,
      isReturned: isReturned ?? this.isReturned,
      returnDueDate: returnDueDate ?? this.returnDueDate,
      remindedCount: remindedCount ?? this.remindedCount,
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
