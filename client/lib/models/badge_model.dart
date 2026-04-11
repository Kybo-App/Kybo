// Modello badge con registro statico dei badge predefiniti dell'app.
// Supporta badge a livelli (bronzo/argento/oro), badge segreti e badge progressivi.
import 'package:flutter/material.dart';

enum BadgeType {
  streak,
  milestone,
  action,
}

enum BadgeTier {
  bronze,
  silver,
  gold,
}

class BadgeModel {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final BadgeType type;
  final bool isSecret;

  /// Per badge progressivi: il contatore Firestore associato (es. 'weight_logs').
  final String? counterKey;

  /// Per badge progressivi: il numero di azioni necessarie per sbloccarlo.
  final int requiredCount;

  /// Tier del badge (null per badge senza tier).
  final BadgeTier? tier;

  /// Colore personalizzato per il badge.
  final Color? color;

  /// Famiglia di appartenenza (per raggruppare bronze/silver/gold).
  final String? family;

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
    this.counterKey,
    this.requiredCount = 1,
    this.tier,
    this.color,
    this.family,
  });

  factory BadgeModel.fromJson(Map<String, dynamic> json) {
    return BadgeModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      icon: IconData(
        json['icon_code'] as int? ?? Icons.star.codePoint,
        fontFamily: 'MaterialIcons',
      ),
      type: BadgeType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => BadgeType.action,
      ),
      isUnlocked: json['is_unlocked'] ?? false,
      unlockedAt: json['unlocked_at'] != null
          ? DateTime.tryParse(json['unlocked_at'])
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

  /// Colore del tier per la visualizzazione.
  Color get tierColor {
    if (tier == null) return const Color(0xFF2E7D32); // primary green
    switch (tier!) {
      case BadgeTier.bronze:
        return const Color(0xFFCD7F32);
      case BadgeTier.silver:
        return const Color(0xFFC0C0C0);
      case BadgeTier.gold:
        return const Color(0xFFFFD700);
    }
  }

  /// Emoji del tier.
  String get tierEmoji {
    if (tier == null) return '';
    switch (tier!) {
      case BadgeTier.bronze:
        return '🥉';
      case BadgeTier.silver:
        return '🥈';
      case BadgeTier.gold:
        return '🥇';
    }
  }

  // ──────────────────────────────────────────────
  //  REGISTRO STATICO DEI BADGE
  // ──────────────────────────────────────────────

  static List<BadgeModel> get registry => [
    // ── AZIONE ─────────────────────────────────
    BadgeModel(
      id: 'first_login',
      title: 'Benvenuto a Bordo',
      description: 'Hai effettuato l\'accesso per la prima volta.',
      icon: Icons.waving_hand_rounded,
      type: BadgeType.action,
    ),

    // ── STREAK (tiered) ────────────────────────
    BadgeModel(
      id: 'streak_3',
      title: 'Costanza',
      description: 'Hai usato l\'app per 3 giorni consecutivi.',
      icon: Icons.local_fire_department_rounded,
      type: BadgeType.streak,
      tier: BadgeTier.bronze,
      family: 'streak',
      counterKey: 'streak_days',
      requiredCount: 3,
      color: const Color(0xFFCD7F32),
    ),
    BadgeModel(
      id: 'streak_7',
      title: 'Una Settimana di Fuoco',
      description: 'Hai usato l\'app per 7 giorni consecutivi.',
      icon: Icons.local_fire_department_rounded,
      type: BadgeType.streak,
      tier: BadgeTier.silver,
      family: 'streak',
      counterKey: 'streak_days',
      requiredCount: 7,
      color: const Color(0xFFC0C0C0),
    ),
    BadgeModel(
      id: 'streak_30',
      title: 'Fiamma Eterna',
      description: 'Hai usato l\'app per 30 giorni consecutivi.',
      icon: Icons.local_fire_department_rounded,
      type: BadgeType.streak,
      tier: BadgeTier.gold,
      family: 'streak',
      counterKey: 'streak_days',
      requiredCount: 30,
      color: const Color(0xFFFFD700),
    ),

    // ── PESO (tiered) ──────────────────────────
    BadgeModel(
      id: 'weight_log_1',
      title: 'Primo Passo',
      description: 'Hai registrato il tuo peso per la prima volta.',
      icon: Icons.monitor_weight_rounded,
      type: BadgeType.action,
      tier: BadgeTier.bronze,
      family: 'weight_log',
      counterKey: 'weight_logs',
      requiredCount: 1,
      color: const Color(0xFFCD7F32),
    ),
    BadgeModel(
      id: 'weight_log_10',
      title: 'Bilancia Amica',
      description: 'Hai registrato il peso 10 volte.',
      icon: Icons.monitor_weight_rounded,
      type: BadgeType.milestone,
      tier: BadgeTier.silver,
      family: 'weight_log',
      counterKey: 'weight_logs',
      requiredCount: 10,
      color: const Color(0xFFC0C0C0),
    ),
    BadgeModel(
      id: 'weight_log_50',
      title: 'Monitoraggio Pro',
      description: 'Hai registrato il peso 50 volte.',
      icon: Icons.monitor_weight_rounded,
      type: BadgeType.milestone,
      tier: BadgeTier.gold,
      family: 'weight_log',
      counterKey: 'weight_logs',
      requiredCount: 50,
      color: const Color(0xFFFFD700),
    ),

    // ── PASTI COMPLETI (tiered) ─────────────────
    BadgeModel(
      id: 'diet_complete',
      title: 'Piatto Pulito',
      description: 'Hai completato tutti i pasti di oggi.',
      icon: Icons.check_circle_outline_rounded,
      type: BadgeType.milestone,
      tier: BadgeTier.bronze,
      family: 'diet_complete',
      counterKey: 'meals_complete_days',
      requiredCount: 1,
      color: const Color(0xFFCD7F32),
    ),
    BadgeModel(
      id: 'diet_complete_7',
      title: 'Settimana Perfetta',
      description: 'Hai completato tutti i pasti per 7 giorni.',
      icon: Icons.check_circle_outline_rounded,
      type: BadgeType.milestone,
      tier: BadgeTier.silver,
      family: 'diet_complete',
      counterKey: 'meals_complete_days',
      requiredCount: 7,
      color: const Color(0xFFC0C0C0),
    ),
    BadgeModel(
      id: 'diet_complete_30',
      title: 'Mese d\'Oro',
      description: 'Hai completato tutti i pasti per 30 giorni.',
      icon: Icons.check_circle_outline_rounded,
      type: BadgeType.milestone,
      tier: BadgeTier.gold,
      family: 'diet_complete',
      counterKey: 'meals_complete_days',
      requiredCount: 30,
      color: const Color(0xFFFFD700),
    ),

    // ── LISTA SPESA (tiered) ───────────────────
    BadgeModel(
      id: 'shopping_list_shared',
      title: 'Condivisione Facile',
      description: 'Hai condiviso la lista della spesa.',
      icon: Icons.share_rounded,
      type: BadgeType.action,
      tier: BadgeTier.bronze,
      family: 'shopping_shared',
      counterKey: 'shopping_shares',
      requiredCount: 1,
      color: const Color(0xFFCD7F32),
    ),
    BadgeModel(
      id: 'shopping_shared_5',
      title: 'Condivisore Seriale',
      description: 'Hai condiviso la lista della spesa 5 volte.',
      icon: Icons.share_rounded,
      type: BadgeType.milestone,
      tier: BadgeTier.silver,
      family: 'shopping_shared',
      counterKey: 'shopping_shares',
      requiredCount: 5,
      color: const Color(0xFFC0C0C0),
    ),
    BadgeModel(
      id: 'shopping_shared_20',
      title: 'Ambasciatore della Spesa',
      description: 'Hai condiviso la lista della spesa 20 volte.',
      icon: Icons.share_rounded,
      type: BadgeType.milestone,
      tier: BadgeTier.gold,
      family: 'shopping_shared',
      counterKey: 'shopping_shares',
      requiredCount: 20,
      color: const Color(0xFFFFD700),
    ),

    // ── SFIDA SETTIMANALE ──────────────────────
    BadgeModel(
      id: 'weekly_challenge',
      title: 'Campione della Settimana',
      description: 'Hai completato almeno 3 pasti al giorno per 5 giorni questa settimana.',
      icon: Icons.emoji_events_rounded,
      type: BadgeType.streak,
    ),

    // ── FEATURE DISCOVERY ──────────────────────
    BadgeModel(
      id: 'cooking_timer_used',
      title: 'Chef Curioso',
      description: 'Hai usato il timer di cottura per la prima volta.',
      icon: Icons.timer_rounded,
      type: BadgeType.action,
    ),
    BadgeModel(
      id: 'ai_explorer',
      title: 'AI Explorer',
      description: 'Hai chiesto suggerimenti all\'intelligenza artificiale.',
      icon: Icons.auto_awesome_rounded,
      type: BadgeType.action,
    ),
    BadgeModel(
      id: 'first_chat_message',
      title: 'Primo Messaggio',
      description: 'Hai inviato un messaggio al nutrizionista.',
      icon: Icons.chat_bubble_rounded,
      type: BadgeType.action,
    ),
    BadgeModel(
      id: 'scale_connected',
      title: 'Connesso',
      description: 'Hai collegato una bilancia smart.',
      icon: Icons.bluetooth_connected_rounded,
      type: BadgeType.action,
    ),
    BadgeModel(
      id: 'pantry_10',
      title: 'Dispensa Piena',
      description: 'Hai aggiunto almeno 10 articoli alla dispensa.',
      icon: Icons.kitchen_rounded,
      type: BadgeType.milestone,
      counterKey: 'pantry_items_added',
      requiredCount: 10,
    ),
    BadgeModel(
      id: 'stats_viewed_5',
      title: 'Analista',
      description: 'Hai visitato la sezione statistiche 5 volte.',
      icon: Icons.bar_chart_rounded,
      type: BadgeType.action,
      counterKey: 'stats_views',
      requiredCount: 5,
    ),

    // ── SEGRETI ────────────────────────────────
    BadgeModel(
      id: 'night_owl',
      title: 'Nottambulo',
      description: 'Hai consumato un pasto dopo mezzanotte.',
      icon: Icons.nightlight_round,
      type: BadgeType.action,
      isSecret: true,
    ),
    BadgeModel(
      id: 'holiday_spirit',
      title: 'Spirito Festivo',
      description: 'Hai usato l\'app il giorno di Natale.',
      icon: Icons.celebration_rounded,
      type: BadgeType.action,
      isSecret: true,
    ),
    BadgeModel(
      id: 'swap_master',
      title: 'Swap Master',
      description: 'Hai scambiato i pasti 10 volte.',
      icon: Icons.swap_horiz_rounded,
      type: BadgeType.milestone,
      isSecret: true,
      counterKey: 'meal_swaps',
      requiredCount: 10,
    ),

    // ── OBIETTIVI PESO ─────────────────────────
    BadgeModel(
      id: 'weight_goal_25',
      title: 'Primo Traguardo',
      description: 'Hai raggiunto il 25% del tuo obiettivo peso.',
      icon: Icons.flag_rounded,
      type: BadgeType.milestone,
      tier: BadgeTier.bronze,
      family: 'weight_goal',
      color: const Color(0xFFCD7F32),
    ),
    BadgeModel(
      id: 'weight_goal_50',
      title: 'Metà Strada',
      description: 'Hai raggiunto il 50% del tuo obiettivo peso.',
      icon: Icons.flag_rounded,
      type: BadgeType.milestone,
      tier: BadgeTier.silver,
      family: 'weight_goal',
      color: const Color(0xFFC0C0C0),
    ),
    BadgeModel(
      id: 'weight_goal_100',
      title: 'Obiettivo Raggiunto!',
      description: 'Hai raggiunto il tuo peso obiettivo!',
      icon: Icons.flag_rounded,
      type: BadgeType.milestone,
      tier: BadgeTier.gold,
      family: 'weight_goal',
      color: const Color(0xFFFFD700),
    ),

    // ── SETTIMANA PERFETTA ─────────────────────
    BadgeModel(
      id: 'perfect_week',
      title: '7 Giorni Perfetti',
      description: 'Aderenza al 100% per 7 giorni consecutivi.',
      icon: Icons.workspace_premium_rounded,
      type: BadgeType.streak,
    ),
  ];
}
