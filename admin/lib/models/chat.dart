import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for a chat between client and nutritionist
class Chat {
  final String id; // chat document ID
  final String clientId;
  final String nutritionistId;
  final String clientName;
  final String clientEmail;
  final String lastMessage;
  final DateTime lastMessageTime;
  final String lastMessageSender; // 'client' or 'nutritionist' or 'admin'
  final int unreadCountClient;
  final int unreadCountNutritionist;
  final String chatType; // 'admin-nutritionist' or 'nutritionist-client'

  Chat({
    required this.id,
    required this.clientId,
    required this.nutritionistId,
    required this.clientName,
    required this.clientEmail,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastMessageSender,
    required this.unreadCountClient,
    required this.unreadCountNutritionist,
    required this.chatType,
  });

  factory Chat.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final participants = data['participants'] as Map<String, dynamic>? ?? {};
    final unreadCount = data['unreadCount'] as Map<String, dynamic>? ?? {};

    return Chat(
      id: doc.id,
      clientId: participants['clientId'] ?? '',
      nutritionistId: participants['nutritionistId'] ?? '',
      clientName: data['clientName'] ?? 'Unknown',
      clientEmail: data['clientEmail'] ?? '',
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessageSender: data['lastMessageSender'] ?? 'client',
      unreadCountClient: unreadCount['client'] ?? 0,
      unreadCountNutritionist: unreadCount['nutritionist'] ?? 0,
      chatType: data['chatType'] ?? 'nutritionist-client', // default to nutritionist-client for backward compatibility
    );
  }
}

/// Model for a single chat message
class ChatMessage {
  final String id;
  final String senderId;
  final String senderType; // 'client' or 'nutritionist'
  final String message;
  final DateTime timestamp;
  final bool read;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderType,
    required this.message,
    required this.timestamp,
    required this.read,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderType: data['senderType'] ?? 'client',
      // Supporta sia 'message' (nuovo) che 'text' (legacy client) per backward compatibility
      message: data['message'] ?? data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: data['read'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderType': senderType,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'read': read,
    };
  }
}
