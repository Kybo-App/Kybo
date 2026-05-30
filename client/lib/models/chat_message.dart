// Modello per un singolo messaggio della chat, serializzabile da/verso Firestore.
// Supporta backward compatibility col campo 'text' legacy (ora rinominato 'message').
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String message;
  final String senderId;
  final String senderType;
  final DateTime timestamp;
  final bool read;
  final String? attachmentUrl;
  final String? attachmentType;
  final String? fileName;

  ChatMessage({
    required this.id,
    required this.message,
    required this.senderId,
    required this.senderType,
    required this.timestamp,
    this.read = false,
    this.attachmentUrl,
    this.attachmentType,
    this.fileName,
  });

  bool get hasAttachment => attachmentUrl != null;

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      message: data['message'] ?? data['text'] ?? '',
      senderId: data['senderId'] ?? '',
      senderType: data['senderType'] ?? 'client',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: data['read'] ?? false,
      attachmentUrl: data['attachmentUrl'],
      attachmentType: data['attachmentType'],
      fileName: data['fileName'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'message': message,
      'senderId': senderId,
      'senderType': senderType,
      'timestamp': Timestamp.fromDate(timestamp),
      'read': read,
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
      if (attachmentType != null) 'attachmentType': attachmentType,
      if (fileName != null) 'fileName': fileName,
    };
  }

}
