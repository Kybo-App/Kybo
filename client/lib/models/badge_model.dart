import 'package:flutter/material.dart';

enum BadgeType {
  streak,
  milestone,
  action,
}

class BadgeModel {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final BadgeType type;
  final bool isSecret;
  
  // Runtime state
  bool isUnlocked;
  DateTime? unlockedAt;

  BadgeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.type,
    this.isSecret = false,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  factory BadgeModel.fromJson(Map<String, dynamic> json) {
    return BadgeModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      icon: IconData(json['icon_code'], fontFamily: 'MaterialIcons'),
      type: BadgeType.values.firstWhere((e) => e.toString() == json['type']),
      isUnlocked: json['is_unlocked'] ?? false,
      unlockedAt: json['unlocked_at'] != null 
          ? DateTime.parse(json['unlocked_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'is_unlocked': isUnlocked,
      'unlocked_at': unlockedAt?.toIso8601String(),
    };
  }

  // Predefined Badges Registry
  static List<BadgeModel> get registry => [
    BadgeModel(
      id: 'first_login',
      title: 'Benvenuto a Bordo',
      description: 'Hai effettuato l\'accesso per la prima volta.',
      icon: Icons.waving_hand_rounded,
      type: BadgeType.action,
    ),
    BadgeModel(
      id: 'streak_3',
      title: 'Costanza',
      description: 'Hai usato l\'app per 3 giorni consecutivi.',
      icon: Icons.local_fire_department_rounded,
      type: BadgeType.streak,
    ),
    BadgeModel(
      id: 'weight_log_1',
      title: 'Primo Passo',
      description: 'Hai registrato il tuo peso per la prima volta.',
      icon: Icons.monitor_weight_rounded,
      type: BadgeType.action,
    ),
     BadgeModel(
      id: 'diet_complete',
      title: 'Piatto Pulito',
      description: 'Hai completato tutti i pasti di oggi.',
      icon: Icons.check_circle_outline_rounded,
      type: BadgeType.milestone,
    ),
  ];
}
