/// A single captured thought — just text plus the metadata that earns its place.
class Thought {
  final String id;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// When the thought was pinned. `null` means not pinned.
  final DateTime? pinnedAt;

  /// When the thought was moved to the trash. `null` means it's a live thought.
  final DateTime? deletedAt;

  const Thought({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
    this.pinnedAt,
    this.deletedAt,
  });

  bool get isPinned => pinnedAt != null;

  bool get isDeleted => deletedAt != null;

  /// The first non-empty line, used as the list preview ("title").
  String get preview {
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  Thought copyWith({
    String? text,
    DateTime? updatedAt,
    DateTime? pinnedAt,
    bool clearPinned = false,
    DateTime? deletedAt,
    bool clearDeleted = false,
  }) {
    return Thought(
      id: id,
      text: text ?? this.text,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pinnedAt: clearPinned ? null : (pinnedAt ?? this.pinnedAt),
      deletedAt: clearDeleted ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    'pinnedAt': pinnedAt?.millisecondsSinceEpoch,
    'deletedAt': deletedAt?.millisecondsSinceEpoch,
  };

  factory Thought.fromJson(Map<String, dynamic> json) {
    final pinnedMs = json['pinnedAt'] as int?;
    final deletedMs = json['deletedAt'] as int?;
    return Thought(
      id: json['id'] as String,
      text: json['text'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int),
      pinnedAt: pinnedMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(pinnedMs),
      deletedAt: deletedMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(deletedMs),
    );
  }
}
