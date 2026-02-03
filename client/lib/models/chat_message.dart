import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single message in the chat
class ChatMessage {
  final String id;
  final String text;
  final String senderId;
  final String senderType; // 'client' | 'nutritionist'
  final DateTime timestamp;
  final bool read;

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderType,
    required this.timestamp,
    this.read = false,
  });

  /// Create ChatMessage from Firestore document
  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      text: data['text'] ?? '',
      senderId: data['senderId'] ?? '',
      senderType: data['senderType'] ?? 'client',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      read: data['read'] ?? false,
    );
  }

  /// Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'text': text,
      'senderId': senderId,
      'senderType': senderType,
      'timestamp': Timestamp.fromDate(timestamp),
      'read': read,
    };
  }

  /// Create a copy with modified fields
  ChatMessage copyWith({
    String? id,
    String? text,
    String? senderId,
    String? senderType,
    DateTime? timestamp,
    bool? read,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      senderId: senderId ?? this.senderId,
      senderType: senderType ?? this.senderType,
      timestamp: timestamp ?? this.timestamp,
      read: read ?? this.read,
    );
  }
}
