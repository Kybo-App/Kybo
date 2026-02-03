import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single message in the chat
/// Campo unificato: 'message' (identico al modello admin)
class ChatMessage {
  final String id;
  final String message;
  final String senderId;
  final String senderType; // 'client' | 'nutritionist' | 'admin'
  final DateTime timestamp;
  final bool read;

  ChatMessage({
    required this.id,
    required this.message,
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
      // Supporta sia 'message' (nuovo) che 'text' (legacy) per backward compatibility
      message: data['message'] ?? data['text'] ?? '',
      senderId: data['senderId'] ?? '',
      senderType: data['senderType'] ?? 'client',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: data['read'] ?? false,
    );
  }

  /// Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'message': message,
      'senderId': senderId,
      'senderType': senderType,
      'timestamp': Timestamp.fromDate(timestamp),
      'read': read,
    };
  }

  /// Create a copy with modified fields
  ChatMessage copyWith({
    String? id,
    String? message,
    String? senderId,
    String? senderType,
    DateTime? timestamp,
    bool? read,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      message: message ?? this.message,
      senderId: senderId ?? this.senderId,
      senderType: senderType ?? this.senderType,
      timestamp: timestamp ?? this.timestamp,
      read: read ?? this.read,
    );
  }
}
