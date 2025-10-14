class MessageModel {
  final int? id;
  final String uid;
  final String subject;
  final String role;     // 'user' | 'model'
  final String content;
  final DateTime createdAt;

  MessageModel({
    this.id,
    required this.uid,
    required this.subject,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'uid': uid,
    'subject': subject,
    'role': role,
    'content': content,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  static MessageModel fromMap(Map<String, Object?> m) => MessageModel(
    id: m['id'] as int?,
    uid: m['uid'] as String,
    subject: m['subject'] as String,
    role: m['role'] as String,
    content: m['content'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
  );
}
