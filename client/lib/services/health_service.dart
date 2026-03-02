// Integrazione Google Fit (Android) / Apple Health (iOS) tramite Health Connect.
// readToday — passi, calorie attive, peso odierni; requestPermissions — richiede accesso health.
// Su dispositivi o piattaforme non supportati restituisce silenziosamente valori null.
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

const _kTypes = [
  HealthDataType.STEPS,
  HealthDataType.ACTIVE_ENERGY_BURNED,
  HealthDataType.WEIGHT,
];

class HealthData {
  final int? steps;
  final double? activeCalories;
  final double? weightKg;

  const HealthData({this.steps, this.activeCalories, this.weightKg});

  bool get isEmpty => steps == null && activeCalories == null && weightKg == null;
}

class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  Future<bool> requestPermissions() async {
    try {
      Health().configure(useHealthConnectIfAvailable: true);
      return await Health().requestAuthorization(_kTypes);
    } catch (e) {
      debugPrint('HealthService: permessi non disponibili — $e');
      return false;
    }
  }

  Future<bool> isAuthorized() async {
    try {
      Health().configure(useHealthConnectIfAvailable: true);
      return await Health().hasPermissions(_kTypes) ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<HealthData> readToday() async {
    try {
      Health().configure(useHealthConnectIfAvailable: true);

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final points = await Health().getHealthDataFromTypes(
        types: _kTypes,
        startTime: startOfDay,
        endTime: now,
      );

      final deduped = Health().removeDuplicates(points);

      int totalSteps = 0;
      double totalCalories = 0;
      double? latestWeight;

      for (final p in deduped) {
        final val = (p.value as NumericHealthValue).numericValue;
        switch (p.type) {
          case HealthDataType.STEPS:
            totalSteps += val.toInt();
          case HealthDataType.ACTIVE_ENERGY_BURNED:
            totalCalories += val;
          case HealthDataType.WEIGHT:
            latestWeight = val.toDouble();
          default:
            break;
        }
      }

      return HealthData(
        steps: totalSteps > 0 ? totalSteps : null,
        activeCalories: totalCalories > 0 ? totalCalories : null,
        weightKg: latestWeight,
      );
    } catch (e) {
      debugPrint('HealthService: lettura dati fallita — $e');
      return const HealthData();
    }
  }
}
