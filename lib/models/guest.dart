class Guest {
  final int? id;
  final String name;
  final String relationship;
  final String? phone;
  final String? note;

  Guest({
    this.id,
    required this.name,
    required this.relationship,
    this.phone,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'relationship': relationship,
      'phone': phone,
      'note': note,
    };
  }

  factory Guest.fromMap(Map<String, dynamic> map) {
    return Guest(
      id: map['id'] as int?,
      name: map['name'] as String,
      relationship: map['relationship'] as String,
      phone: map['phone'] as String?,
      note: map['note'] as String?,
    );
  }

  Guest copyWith({
    int? id,
    String? name,
    String? relationship,
    String? phone,
    String? note,
  }) {
    return Guest(
      id: id ?? this.id,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      phone: phone ?? this.phone,
      note: note ?? this.note,
    );
  }
}

// 关系类型常量
class RelationshipTypes {
  static const String family = '家人';
  static const String relative = '亲戚';
  static const String friend = '朋友';
  static const String colleague = '同事';
  static const String classmate = '同学';
  static const String neighbor = '邻居';
  static const String other = '其他';

  static List<String> get all => [
    family,
    relative,
    friend,
    colleague,
    classmate,
    neighbor,
    other,
  ];
}
