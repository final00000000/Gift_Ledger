class EventBook {
  final int? id;
  final String name;
  final String type;
  final DateTime date;
  final String? lunarDate;
  final String? note;
  final DateTime createdAt;

  EventBook({
    this.id,
    required this.name,
    required this.type,
    required this.date,
    this.lunarDate,
    this.note,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'date': date.toIso8601String(),
      'lunarDate': lunarDate,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory EventBook.fromMap(Map<String, dynamic> map) {
    return EventBook(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      date: DateTime.parse(map['date'] as String),
      lunarDate: map['lunarDate'] as String?,
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  EventBook copyWith({
    int? id,
    String? name,
    String? type,
    DateTime? date,
    String? lunarDate,
    String? note,
    DateTime? createdAt,
  }) {
    return EventBook(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      date: date ?? this.date,
      lunarDate: lunarDate ?? this.lunarDate,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
