// Provider principale per la gestione della dieta, dispensa, swap e sync cloud.
// runSmartSyncCheck — esegue sync differenziale verso Firestore (veloce <3h, storico >3h).
// _recalcAvailability — ricalcola la disponibilità ingredienti su Isolate separato.
// getDays/getMeals/getRelaxableFoods — restituiscono config dieta con fallback a global config.
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kybo/logic/diet_logic.dart';
import '../repositories/diet_repository.dart';
import '../services/storage_service.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/encryption_service.dart';
import '../models/pantry_item.dart';
import '../models/active_swap.dart';
import '../logic/diet_calculator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/notification_service.dart';
import '../models/diet_models.dart';
import '../services/tracking_service.dart';
import '../models/tracking_models.dart';
import '../services/badge_service.dart';
import '../services/xp_service.dart';
import '../services/challenge_service.dart';
import '../services/pricing_service.dart';
import '../utils/time_helper.dart';

class DietProvider extends ChangeNotifier {
  final DietRepository _repository;
  final StorageService _storage = StorageService();
  final FirestoreService _firestore = FirestoreService();
  final AuthService _auth = AuthService();
  final TrackingService _trackingService = TrackingService();
  final BadgeService _badgeService;
  final XpService _xpService;
  final ChallengeService _challengeService;

  DietPlan? _dietPlan;
  int _selectedWeek = 0;
  List<PantryItem> _pantryItems = [];
  Map<String, ActiveSwap> _activeSwaps = {};
  List<String> _shoppingList = [];
  double? _weeklyBudget;
  Map<String, bool> _availabilityMap = {};
  Map<String, double> _conversions = {};
  bool _isCalculating = false;
  DateTime? _calculationStartTime;

  /// True quando l'utente sta sfogliando una dieta storica (read-only).
  /// In questo stato:
  /// - Le scritture locali (saveDiet) sono inibite per non sporcare la cache
  ///   con dati storici e non far avanzare il `diet_local_updated_at_ms` —
  ///   altrimenti il prossimo syncFromFirebase pusherebbe lo storico in
  ///   `diets/current` sovrascrivendo la dieta vera.
  /// - Le sync verso cloud (runSmartSyncCheck) sono inibite per lo stesso motivo.
  /// Cleared automaticamente da loadFromCache / syncFromFirebase / uploadDiet.
  bool _isViewingHistorical = false;

  DateTime _lastCloudSave = DateTime.fromMillisecondsSinceEpoch(0);
  Map<String, dynamic>? _lastSyncedDiet;
  Map<String, dynamic>? _lastSyncedSubstitutions;


  static const Duration _cloudSaveInterval = Duration(hours: 3);

  Set<String>? _globalRelaxableFoods;
  List<String>? _globalDays;
  List<String>? _globalMeals;

  Map<String, dynamic>? _lastRawParsedData;
  Map<String, dynamic>? get lastRawParsedData => _lastRawParsedData;

  bool _isLoading = false;
  bool _isTranquilMode = false;
  double _uploadProgress = 0.0;
  final NotificationService _notificationService =
      NotificationService();

  bool _needsNotificationPermissions = false;
  bool get needsNotificationPermissions => _needsNotificationPermissions;

  void resetPermissionFlag() {
    _needsNotificationPermissions = false;
  }

  Future<String> runSmartSyncCheck({bool forceSync = false}) async {
    final user = _auth.currentUser;
    if (user == null || _dietPlan == null) return "Errore: Dati mancanti.";
    if (_isViewingHistorical) {
      debugPrint("⏭️ Sync skip: stiamo visualizzando una dieta storica (view-only).");
      return "ℹ️ Visualizzazione storica — nessuna sincronizzazione.";
    }

    final currentDietJson = _dietPlan!.toJson();
    final currentPlanJson = currentDietJson['plan'] as Map<String, dynamic>;
    final currentSubsJson = currentDietJson['substitutions'] as Map<String, dynamic>;
    final currentWeeksJson = currentDietJson['weeks'] as List<dynamic>?;

    bool hasSwapsChanged = _activeSwaps.isNotEmpty;
    bool hasStructuralChanges =
        _hasStructuralChanges(currentPlanJson, _lastSyncedDiet) ||
            hasSwapsChanged;

    if (!hasStructuralChanges && !forceSync) return "✅ Nessuna modifica.";

    final now = DateTime.now();

    final Map<String, dynamic> swapsToSave = {};
    _activeSwaps.forEach((k, v) => swapsToSave[k] = v.toMap());

    final configJson = _dietPlan!.config?.toJson();

    if (!forceSync && now.difference(_lastCloudSave).inHours < 3) {
      await _firestore.saveCurrentDiet(
        _sanitize(currentPlanJson),
        _sanitize(currentSubsJson),
        swapsToSave,
        weeks: currentWeeksJson,
        config: configJson,
      );
      return "☁️ Modifiche sincronizzate.";
    }

    try {
      await _firestore.saveCurrentDiet(
        _sanitize(currentPlanJson),
        _sanitize(currentSubsJson),
        swapsToSave,
        weeks: currentWeeksJson,
        config: configJson,
      );

      if (_currentFirestoreId == null) {
        String newId = await _firestore.saveDietToHistory(
          _sanitize(currentPlanJson),
          _sanitize(currentSubsJson),
          swapsToSave,
          weeks: currentWeeksJson,
          config: configJson,
        );
        _currentFirestoreId = newId;
      } else {
        await _firestore.updateDietHistory(
          _currentFirestoreId!,
          _sanitize(currentPlanJson),
          _sanitize(currentSubsJson),
          swapsToSave,
          weeks: currentWeeksJson,
          config: configJson,
        );
      }

      _lastCloudSave = now;
      _lastSyncedDiet = _deepCopy(currentPlanJson);
      return "✅ Backup Storico e Sync completati.";
    } catch (e) {
      return "❌ Errore Sync: $e";
    }
  }

  Future<void> _triggerSmartSyncCheck() async {
    if (_auth.currentUser != null && _dietPlan != null) {
      bool timePassed =
          DateTime.now().difference(_lastCloudSave) > _cloudSaveInterval;

      final currentDietJson = _dietPlan!.toJson();
      final currentPlanJson = currentDietJson['plan'] as Map<String, dynamic>;
      final currentSubsJson = currentDietJson['substitutions'] as Map<String, dynamic>;

      bool isStructurallyDifferent = _hasStructuralChanges(
              currentPlanJson, _lastSyncedDiet) ||
          jsonEncode(currentSubsJson) != jsonEncode(_lastSyncedSubstitutions);

      if (timePassed && isStructurallyDifferent) {
        await runSmartSyncCheck(forceSync: true);
        debugPrint("☁️ Auto-Sync attivato da modifica manuale");
      }
    }
  }

  DietPlan? get dietPlan => _dietPlan;
  String? _currentFirestoreId;
  List<PantryItem> get pantryItems => _pantryItems;
  Map<String, ActiveSwap> get activeSwaps => _activeSwaps;
  List<String> get shoppingList => _shoppingList;
  double? get weeklyBudget => _weeklyBudget;

  /// Costo stimato totale della lista spesa corrente (solo articoli non spuntati)
  double get estimatedShoppingCost {
    final activeItems = _shoppingList
        .where((item) => !item.startsWith('OK_'))
        .toList();
    return PricingService.estimateTotalCost(activeItems);
  }

  /// Percentuale del budget usata (0.0–1.0+), null se nessun budget impostato
  double? get budgetUsageRatio {
    if (_weeklyBudget == null || _weeklyBudget! <= 0) return null;
    return estimatedShoppingCost / _weeklyBudget!;
  }

  Map<String, bool> get availabilityMap => _availabilityMap;
  bool get isLoading => _isLoading;
  bool get isTranquilMode => _isTranquilMode;
  double get uploadProgress => _uploadProgress;

  /// Settimana attualmente visualizzata (0-indexed)
  int get selectedWeek => _selectedWeek;

  /// Numero totale di settimane nel piano corrente
  int get weekCount => _dietPlan?.weekCount ?? 1;

  /// Piano della settimana attualmente selezionata
  Map<String, Map<String, List<Dish>>> get currentWeekPlan {
    if (_dietPlan == null || _dietPlan!.weeks.isEmpty) return {};
    final idx = _selectedWeek.clamp(0, _dietPlan!.weeks.length - 1);
    return _dietPlan!.weeks[idx];
  }

  /// Cambia la settimana visualizzata e notifica i listener
  void setWeek(int week) {
    if (_dietPlan == null) return;
    final clamped = week.clamp(0, _dietPlan!.weekCount - 1);
    if (clamped == _selectedWeek) return;
    _selectedWeek = clamped;
    notifyListeners();
  }

  /// Restituisce i giorni dalla config della dieta, inferiti dal piano, o da global config.
  List<String> getDays() {
    final config = _dietPlan?.config;
    if (config != null && config.days.isNotEmpty) {
      return config.days;
    }

    if (_dietPlan != null && currentWeekPlan.isNotEmpty) {
      final daysFromPlan = currentWeekPlan.keys.toList();

      final referenceOrder = (_globalDays != null && _globalDays!.isNotEmpty)
          ? _globalDays!
          : [];

      daysFromPlan.sort((a, b) {
        int idxA = referenceOrder.indexOf(a);
        int idxB = referenceOrder.indexOf(b);
        if (idxA == -1) idxA = 999;
        if (idxB == -1) idxB = 999;
        return idxA.compareTo(idxB);
      });

      return daysFromPlan;
    }

    if (_globalDays != null && _globalDays!.isNotEmpty) {
      return _globalDays!;
    }

    return [];
  }

  /// Restituisce i tipi di pasto dalla config della dieta con smart merge per preservare l'ordine.
  List<String> getMeals() {
    final config = _dietPlan?.config;
    if (config != null && config.meals.isNotEmpty) {
      return config.meals;
    }

    if (_dietPlan != null && currentWeekPlan.isNotEmpty) {
      List<String> masterList = [];

      final days = getDays();

      for (var day in days) {
        final dayMealsMap = currentWeekPlan[day];
        if (dayMealsMap == null) continue;

        final dayMeals = dayMealsMap.keys.toList();

        int mIndex = 0;
        for (var meal in dayMeals) {
          if (masterList.contains(meal)) {
            int existingIndex = masterList.indexOf(meal);
            if (existingIndex >= mIndex) {
              mIndex = existingIndex + 1;
            }
          } else {
            if (mIndex < masterList.length) {
              masterList.insert(mIndex, meal);
            } else {
              masterList.add(meal);
            }
            mIndex++;
          }
        }
      }

      if (masterList.isNotEmpty) {
        return masterList;
      }
    }

    if (_globalMeals != null && _globalMeals!.isNotEmpty) {
      return _globalMeals!;
    }

    return [];
  }

  /// Restituisce i relaxable foods dalla config della dieta o da global config.
  Set<String> getRelaxableFoods() {
    final config = _dietPlan?.config;
    if (config != null && config.relaxableFoods.isNotEmpty) {
      return config.relaxableFoods;
    }
    if (config != null && config.relaxableFoods.isNotEmpty) {
      return config.relaxableFoods;
    }
    if (_globalRelaxableFoods != null && _globalRelaxableFoods!.isNotEmpty) {
      return _globalRelaxableFoods!;
    }
    return {};
  }

  /// Verifica se un alimento è relaxable con matching singolare/plurale e blacklist.
  bool isRelaxable(String foodName) {
    final relaxableSet = getRelaxableFoods();
    if (relaxableSet.isEmpty) return false;

    final String lowerName = foodName.toLowerCase();

    const blacklist = [
      'marmellata', 'confettura', 'olio', 'burro', 'margarina',
      'zucchero', 'miele', 'pane', 'pasta', 'crema', 'succo'
    ];
    for (String banned in blacklist) {
      if (lowerName.contains(banned)) return false;
    }

    for (String tag in relaxableSet) {
      if (lowerName.contains(tag)) return true;
    }

    for (String tag in relaxableSet) {
      if (tag.length < 3) continue;

      if (tag.endsWith('cia') || tag.endsWith('gia')) {
         String stemShort = tag.substring(0, tag.length - 2);
         if (lowerName.contains(stemShort)) return true;
      }

      String stem = tag.substring(0, tag.length - 1);

      if (lowerName.contains(stem)) {
        return true;
      }
    }

    return false;
  }

  /// Restituisce l'indice del giorno corrente nella lista dei giorni della dieta, -1 se non trovato.
  int getTodayIndex() {
    final days = getDays();
    if (days.isEmpty) return -1;

    final today = TimeHelper().getLogicalToday();
    int weekdayIndex = today.weekday - 1;

    if (weekdayIndex >= 0 && weekdayIndex < days.length) {
      return weekdayIndex;
    }
    return 0;
  }

  /// Restituisce il nome del giorno corrente secondo la config della dieta.
  String getTodayName() {
    final days = getDays();
    final index = getTodayIndex();
    if (index >= 0 && index < days.length) {
      return days[index];
    }
    return days.isNotEmpty ? days.first : '';
  }

  DietProvider(this._repository, this._badgeService, this._xpService, this._challengeService);

  Future<bool> loadFromCache() async {
    bool hasData = false;
    // Fresh startup: la cache rappresenta la dieta corrente reale, non
    // uno storico. Reset esplicito del flag — altrimenti se l'app è
    // crashata mentre era in view-only mode resteremmo bloccati.
    _isViewingHistorical = false;
    try {
      _setLoading(true);
      final savedDiet = await _storage.loadDiet();
      _pantryItems = await _storage.loadPantry();
      _activeSwaps = await _storage.loadSwaps();
      _conversions = await _storage.loadConversions();
      _shoppingList = await _storage.loadShoppingList();
      await _loadBudget();

      if (savedDiet != null && savedDiet['plan'] != null) {
        _dietPlan = DietPlan.fromJson(savedDiet);

        _lastSyncedDiet = _deepCopy(savedDiet['plan']);
        _lastSyncedSubstitutions = _deepCopy(savedDiet['substitutions']);

        await _checkDailyReset();

        _recalcAvailability();
        hasData = true;
      }
    } catch (e) {
      debugPrint("⚠️ Errore Cache: $e");
    } finally {
      _setLoading(false);
    }

    _fetchGlobalConfig();

    notifyListeners();
    return hasData;
  }

  Future<void> syncFromFirebase(String uid) async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('diets')
          .doc('current')
          .get();

      // [FIX 2026-05-25] Il doc `diets/current` può avere campi legacy non
      // crittografati (`plan`, `substitutions`, `activeSwaps`) lasciati da
      // scritture pre-encryption. `saveCurrentDiet` usa `SetOptions(merge: true)`
      // e non li rimuove → convivono coi campi `_encrypted` recenti.
      //
      // Prima qui si leggeva `data['plan']` direttamente, prendendo quindi il
      // fossile vecchio (senza sostituzioni) e ignorando `plan_encrypted`
      // (la dieta attuale). Risultato: ogni sync sovrascriveva la cache
      // locale corretta con la dieta vecchia.
      //
      // Fix: se `encrypted == true`, decifra i campi `_encrypted` e costruisci
      // un payload coerente con la stessa shape attesa da DietPlan.fromJson.
      // I campi legacy vengono completamente ignorati.
      final rawData = docSnapshot.data();
      Map<String, dynamic>? data;
      if (rawData != null) {
        if (rawData['encrypted'] == true) {
          try {
            final encSvc = EncryptionService();
            data = <String, dynamic>{
              'plan': encSvc.decryptData(rawData['plan_encrypted'] as String, uid),
              'substitutions': encSvc.decryptData(rawData['substitutions_encrypted'] as String, uid),
              'activeSwaps': encSvc.decryptData(rawData['activeSwaps_encrypted'] as String, uid),
              'lastUpdated': rawData['lastUpdated'],
              'uploadedAt': rawData['uploadedAt'],
            };
            if (rawData['weeks_encrypted'] != null) {
              final decryptedWeeks = encSvc.decryptData(
                rawData['weeks_encrypted'] as String,
                uid,
              );
              if (decryptedWeeks['weeks'] is List) {
                data['weeks'] = decryptedWeeks['weeks'];
              }
            }
            // [FIX 2026-05-25] `config` (days/meals/relaxable_foods) è
            // memorizzata in chiaro accanto ai campi crittografati. Senza
            // questa lettura, l'app dopo il sync aveva `_dietPlan.config = null`
            // e cadeva nel fallback fragile dell'ordine giorni/pasti
            // (vedi bug "venerdì invece di lunedì" + "pasti disordinati").
            if (rawData['config'] != null) {
              data['config'] = rawData['config'];
            }
            debugPrint("🔓 Sync cloud: decifrati campi crittografati "
                "(plan ${(data['plan'] as Map?)?.keys.length ?? 0} giorni, "
                "subs ${(data['substitutions'] as Map?)?.keys.length ?? 0} gruppi, "
                "config=${data['config'] != null})");
          } catch (e) {
            debugPrint("❌ Sync cloud: errore decifratura: $e");
            return;
          }
        } else {
          // Legacy: doc senza encrypted flag → usa campi in chiaro come prima.
          data = rawData;
        }
      }

      // Last-write-wins: se la cache locale è più recente del doc `current`
      // su Firestore, non sovrascriviamo la dieta locale — sarebbe un regresso
      // (es. swap/sostituzioni fatte tra due flutter run prima che il throttle
      // di runSmartSyncCheck permettesse il push). Invece pushiamo il locale
      // verso il cloud così le due repliche tornano allineate.
      final localUpdatedAt = await _storage.loadDietLocalUpdatedAt();
      if (docSnapshot.exists && _dietPlan != null && localUpdatedAt != null) {
        final cloudTs = data?['lastUpdated'];
        DateTime? cloudUpdatedAt;
        if (cloudTs is Timestamp) cloudUpdatedAt = cloudTs.toDate();
        if (cloudUpdatedAt == null ||
            localUpdatedAt.isAfter(cloudUpdatedAt)) {
          debugPrint(
              "⬆️ Local diet is newer than cloud — pushing up instead of pulling");
          final jsonMap = _dietPlan!.toJson();
          final swapsMap = <String, dynamic>{};
          _activeSwaps.forEach((k, v) => swapsMap[k] = v.toMap());
          await _firestore.saveCurrentDiet(
            _sanitize(jsonMap['plan'] as Map<String, dynamic>),
            _sanitize(jsonMap['substitutions'] as Map<String, dynamic>),
            swapsMap,
            weeks: jsonMap['weeks'] as List<dynamic>?,
            config: jsonMap['config'] as Map<String, dynamic>?,
          );
          _lastSyncedDiet = _deepCopy(jsonMap['plan'] as Map<String, dynamic>);
          _lastSyncedSubstitutions =
              _deepCopy(jsonMap['substitutions'] as Map<String, dynamic>);
          _lastCloudSave = DateTime.now();
          return;
        }
      }

      if (docSnapshot.exists) {
        if (data != null && data['plan'] != null) {
          // Sync da cloud → torniamo allo stato "current vera". Esci dalla
          // view-only mode (se eravamo in storico).
          _isViewingHistorical = false;
          final Map<String, bool> localConsumedStates = {};
          if (_dietPlan != null) {
            for (final weekPlan in _dietPlan!.weeks) {
              weekPlan.forEach((day, meals) {
                meals.forEach((mealType, dishes) {
                  for (var dish in dishes) {
                    if (dish.isConsumed) {
                      localConsumedStates[dish.instanceId] = true;
                    }
                  }
                });
              });
            }
          }

          _dietPlan = DietPlan.fromJson(data);

          if (localConsumedStates.isNotEmpty) {
            for (final weekPlan in _dietPlan!.weeks) {
              weekPlan.forEach((day, meals) {
                meals.forEach((mealType, dishes) {
                  for (var dish in dishes) {
                    if (localConsumedStates[dish.instanceId] == true) {
                      dish.isConsumed = true;
                    }
                  }
                });
              });
            }
            debugPrint("🔄 Ripristinati ${localConsumedStates.length} stati consumo (multi-week)");
          }

          await _storage.saveDiet(_dietPlan!.toJson());
          // Appena pullato dal cloud: allinea il local mtime al `lastUpdated`
          // del doc remoto, altrimenti saveDiet avrebbe stampato `now()` e il
          // prossimo syncFromFirebase penserebbe che il local è più recente
          // e farebbe un push inutile.
          final cloudTs = data['lastUpdated'];
          if (cloudTs is Timestamp) {
            await _storage.setDietLocalUpdatedAt(cloudTs.toDate());
          }

          final jsonMap = _dietPlan!.toJson();
          _lastSyncedDiet = _deepCopy(jsonMap['plan']);
          _lastSyncedSubstitutions = _deepCopy(jsonMap['substitutions']);
          _lastCloudSave = DateTime.now();

          await _checkDailyReset();

          _recalcAvailability();
          await scheduleMealNotifications();
          await _updateDailyStats();
          notifyListeners();
          debugPrint("☁️ Sync Cloud completato (da 'current')");
        }
      }
    } catch (e) {
      debugPrint("⚠️ Sync Cloud fallito: $e");
    }
  }

  /// Imposta una dieta dallo storico come "current" — sia in locale che su Firestore.
  ///
  /// [FIX 2026-05-25 v2] Prima questa funzione salvava la dieta storica solo nella
  /// cache locale stampando `diet_local_updated_at_ms = NOW`, ma NON la pushava
  /// subito in `diets/current` su Firestore. Al prossimo `syncFromFirebase` il
  /// check "last-write-wins" vedeva il local più recente del cloud current
  /// (vecchio) e pushava la storica al posto della current — bug giusto, ma a
  /// scoppio ritardato e impredicibile. Inoltre, se l'utente uccideva l'app
  /// prima del sync, alla riapertura `loadFromCache` riprendeva la storica
  /// dalla cache come se fosse la current, creando ambiguità.
  ///
  /// Fix: push immediato e sincrono a Firestore `diets/current` con i nuovi
  /// dati. Cache locale e cloud rimangono allineati senza race.
  Future<void> loadHistoricalDiet(Map<String, dynamic> dietData, String docId) async {
    debugPrint("📂 Restore dieta storica come current — ID: $docId");

    _isViewingHistorical = false;
    _dietPlan = DietPlan.fromJson(dietData);
    _currentFirestoreId = docId;
    _selectedWeek = 0;

    _activeSwaps = {};

    if (dietData['activeSwaps'] != null) {
      try {
        final rawSwaps = dietData['activeSwaps'] as Map;
        rawSwaps.forEach((key, value) {
          if (value is Map) {
            final swapObj =
                ActiveSwap.fromMap(Map<String, dynamic>.from(value));
            _activeSwaps[key.toString()] = swapObj;
          }
        });
        debugPrint("✅ Ripristinati ${_activeSwaps.length} scambi attivi.");
      } catch (e) {
        debugPrint("⚠️ Errore critico ripristino swap: $e");
      }
    }

    final jsonMap = _dietPlan!.toJson();
    _lastSyncedDiet = _deepCopy(jsonMap['plan']);
    _lastSyncedSubstitutions = _deepCopy(jsonMap['substitutions']);

    // UI snappy: notifica subito, prima delle scritture lente.
    notifyListeners();
    _recalcAvailability();

    // Local cache (saveDiet stampa diet_local_updated_at_ms = NOW).
    await _storage.saveDiet(_dietPlan!.toJson());
    await _storage.saveSwaps(_activeSwaps);

    // [FIX] Push immediato in Firestore `diets/current` per allineare
    // cloud e local. Senza questo, il client locale sarebbe stampato NOW
    // e il cloud current resterebbe la dieta vecchia → last-write-wins al
    // prossimo sync recupererebbe in qualche modo, ma con race nel mezzo
    // (e se l'utente killasse subito l'app, il loadFromCache successivo
    // ricaricherebbe lo stato giusto dal local, però il sync background
    // potrebbe ancora vedere disallineamenti).
    if (_auth.currentUser != null) {
      try {
        final swapsMap = <String, dynamic>{};
        _activeSwaps.forEach((k, v) => swapsMap[k] = v.toMap());
        await _firestore.saveCurrentDiet(
          _sanitize(jsonMap['plan'] as Map<String, dynamic>),
          _sanitize(jsonMap['substitutions'] as Map<String, dynamic>),
          swapsMap,
          weeks: jsonMap['weeks'] as List<dynamic>?,
          config: jsonMap['config'] as Map<String, dynamic>?,
        );
        _lastCloudSave = DateTime.now();
        debugPrint("☁️ Storica pushata in diets/current.");
      } catch (e) {
        debugPrint("⚠️ Push storica → current fallito: $e (local è comunque corretto, sync futuro recupera)");
      }
    }
  }

  Future<void> refreshAvailability() async {
    await _recalcAvailability();
  }

  /// Controlla se il giorno è cambiato e resetta tutti i flag isConsumed su tutte le settimane.
  Future<void> _checkDailyReset() async {
    if (_dietPlan == null) return;
    if (_isViewingHistorical) {
      // In view-only non resettare nulla né stampare timestamp.
      // Quando torneremo alla current, sarà la sync (o un nuovo loadFromCache)
      // a riprendere lo stato giusto.
      return;
    }

    final todayStr = TimeHelper().getLogicalTodayString();

    final lastResetDate = await _storage.loadLastConsumedResetDate();

    if (lastResetDate == todayStr) return;

    bool anyReset = false;
    for (final weekPlan in _dietPlan!.weeks) {
      weekPlan.forEach((day, meals) {
        meals.forEach((mealType, dishes) {
          for (var dish in dishes) {
            if (dish.isConsumed) {
              dish.isConsumed = false;
              anyReset = true;
            }
          }
        });
      });
    }

    await _storage.saveLastConsumedResetDate(todayStr);
    if (anyReset) {
      await _storage.saveDiet(_dietPlan!.toJson());
      debugPrint('🔄 Reset giornaliero consumed completato ($todayStr)');
    }
  }

  Future<void> updateDietMeal(
    String day,
    String meal,
    int unsafeIndex,
    String name,
    String qty, {
    String? instanceId,
    int? cadCode,
  }) async {
    if (_isViewingHistorical) {
      debugPrint("⏭️ updateDietMeal skip: dieta storica view-only.");
      return;
    }
    if (_dietPlan == null ||
        !currentWeekPlan.containsKey(day) ||
        !currentWeekPlan[day]!.containsKey(meal)) {
      return;
    }

    final List<Dish> currentMeals = currentWeekPlan[day]![meal]!;

    int realIndex = unsafeIndex;
    if (instanceId != null || cadCode != null) {
      final foundIndex = currentMeals.indexWhere((d) {
        if (instanceId != null && d.instanceId == instanceId) return true;
        if (cadCode != null && d.cadCode == cadCode) return true;
        return false;
      });

      if (foundIndex != -1) {
        realIndex = foundIndex;
      } else {
        debugPrint("⚠️ Update annullato: Piatto non trovato.");
        return;
      }
    }

    if (realIndex >= 0 && realIndex < currentMeals.length) {
      final oldDish = currentMeals[realIndex];

      final newDish = Dish(
        instanceId: oldDish.instanceId,
        name: name,
        qty: qty,
        cadCode: oldDish.cadCode,
        isComposed: oldDish.isComposed,
        ingredients: oldDish.ingredients,
        isConsumed: oldDish.isConsumed,
      );

      currentMeals[realIndex] = newDish;

      await _storage.saveDiet(_dietPlan!.toJson());

      await _triggerSmartSyncCheck();

      await _recalcAvailability();
      await _updateDailyStats();
      notifyListeners();
    }
  }

  Future<void> consumeMeal(
    String day,
    String mealType,
    int unsafeIndex, {
    bool force = false,
    String? instanceId,
    int? cadCode,
  }) async {
    if (_isViewingHistorical) {
      debugPrint("⏭️ consumeMeal skip: dieta storica view-only.");
      return;
    }
    if (_dietPlan == null) return;

    final mealsMap = currentWeekPlan[day];
    if (mealsMap == null || !mealsMap.containsKey(mealType)) return;

    final List<Dish> meals = mealsMap[mealType]!;

    int realIndex = unsafeIndex;
    if (instanceId != null || cadCode != null) {
      final foundIndex = meals.indexWhere((d) {
        if (instanceId != null && d.instanceId == instanceId) return true;
        if (cadCode != null && d.cadCode == cadCode) return true;
        return false;
      });
      if (foundIndex != -1) realIndex = foundIndex;
    }

    if (realIndex >= meals.length) return;

    final mealsAsMaps = meals.map((e) => e.toJson()).toList();
    List<List<int>> groups = DietCalculator.buildGroups(mealsAsMaps);

    List<int> targetGroupIndices = [];
    for (int g = 0; g < groups.length; g++) {
      if (groups[g].contains(realIndex)) {
        targetGroupIndices = groups[g];
        break;
      }
    }
    if (targetGroupIndices.isEmpty) targetGroupIndices = [realIndex];

    List<Map<String, String>> allIngredientsToProcess = [];
    for (int i in targetGroupIndices) {
      var dish = meals[i];
      var ingredients = DietLogic.resolveIngredients(
        dish: dish,
        day: day,
        mealType: mealType,
        activeSwaps: _activeSwaps,
      );
      allIngredientsToProcess.addAll(ingredients);
    }

    if (!force) {
      for (var ing in allIngredientsToProcess) {
        DietLogic.validateItem(
          name: ing['name']!,
          rawQtyString: ing['qty']!,
          pantryItems: _pantryItems,
          conversions: _conversions,
        );
      }
    }

    bool pantryModified = false;
    for (var ing in allIngredientsToProcess) {
      bool changed = DietLogic.consumeItem(
        name: ing['name']!,
        rawQtyString: ing['qty']!,
        pantryItems: _pantryItems,
        conversions: _conversions,
      );
      if (changed) pantryModified = true;
    }

    if (pantryModified) {
      _storage.savePantry(_pantryItems);
    }

    for (int i in targetGroupIndices) {
      if (i < meals.length) {
        final old = meals[i];
        meals[i] = Dish(
          instanceId: old.instanceId,
          name: old.name,
          qty: old.qty,
          cadCode: old.cadCode,
          isComposed: old.isComposed,
          ingredients: old.ingredients,
          isConsumed: true,
        );
      }
    }

    await _storage.saveDiet(_dietPlan!.toJson());

    // Award XP per pasto consumato
    await _xpService.addXp(XpRewards.mealConsumed, 'meal_consumed');

    // Auto-complete sfide relative ai pasti
    await _challengeService.checkAutoComplete('complete_1_meal');

    await _recalcAvailability();
    await _updateDailyStats();
  }


  /// Calcola e salva le statistiche giornaliere tramite TrackingService.
  Future<void> _updateDailyStats() async {
    if (_dietPlan == null) return;

    final todayName = getTodayName();
    if (todayName.isEmpty || !currentWeekPlan.containsKey(todayName)) return;

    final dayMeals = currentWeekPlan[todayName]!;

    int planned = 0;
    int consumed = 0;

    dayMeals.forEach((mealType, dishes) {
      if (dishes.isNotEmpty) {
        planned++;
        if (dishes.every((d) => d.isConsumed)) {
          consumed++;
        }
      }
    });

    try {
      final stats = DailyMealStats(
        date: DateTime.now(),
        mealsPlanned: planned,
        mealsConsumed: consumed,
        mealCompletion: {},
      );
      await _trackingService.saveDailyStats(stats);

      await _badgeService.checkDailyGoals(planned, consumed);

      // XP bonus e sfide per giornata completa
      if (planned > 0 && consumed == planned) {
        await _xpService.addXp(XpRewards.allMealsComplete, 'all_meals_complete');
        await _challengeService.checkAutoComplete('complete_all_meals');
      }
      if (consumed >= 2) {
        await _challengeService.checkAutoComplete('complete_2_meals');
      }
    } catch (e) {
      debugPrint("⚠️ Errore aggiornamento stats: $e");
    }
  }

  Future<void> resolveUnitMismatch(
    String itemName,
    String fromUnit,
    String toUnit,
    double factor,
  ) async {
    final key =
        "${itemName.trim().toLowerCase()}_${fromUnit.trim().toLowerCase()}_to_${toUnit.trim().toLowerCase()}";
    _conversions[key] = factor;
    await _storage.saveConversions(_conversions);
    notifyListeners();
  }

  Future<void> uploadDiet(String path) async {
    _setLoading(true);
    _uploadProgress = 0.0;
    // Nuova dieta in arrivo → diventa la nuova "current". Esci dalla view-only.
    _isViewingHistorical = false;

    try {
      String? token;
      try {
        token = await FirebaseMessaging.instance.getToken();
      } catch (_) {}

      final result = await _repository.uploadDiet(
        path,
        fcmToken: token,
        onProgress: (progress) {
          _uploadProgress = progress;
          notifyListeners();
        },
      );

      _uploadProgress = 1.0;

      _lastRawParsedData = result;

      _dietPlan = DietPlan.fromJson(result);
      _selectedWeek = 0;

      await _storage.saveDiet(_dietPlan!.toJson());

      _activeSwaps = {};
      await _storage.saveSwaps({});

      if (_auth.currentUser != null) {
        _lastCloudSave = DateTime.now();
        final jsonPlan = _dietPlan!.toJson();
        _lastSyncedDiet = _deepCopy(jsonPlan['plan'] as Map<String, dynamic>);
        _lastSyncedSubstitutions = _deepCopy(jsonPlan['substitutions'] as Map<String, dynamic>);
      }

      _recalcAvailability();
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<int> scanReceipt(String path) async {
    _setLoading(true);
    int count = 0;
    try {
      final items = await _repository.scanReceipt(path, _extractAllowedFoods());
      for (var item in items) {
        if (item is Map && item.containsKey('name')) {
          String rawQty = item['quantity']?.toString() ?? "1";
          double qty = DietCalculator.parseQty(rawQty);
          String unit = DietCalculator.parseUnit(rawQty, item['name']);
          if (rawQty.toLowerCase().contains('l') &&
              !rawQty.toLowerCase().contains('ml')) {
            qty *= 1000;
          }
          if (rawQty.toLowerCase().contains('kg')) qty *= 1000;
          addPantryItem(item['name'], qty, unit);
          count++;
        }
      }
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
    return count;
  }

  void addPantryItem(String name, double qty, String unit) {
    final normalizedName = name.trim().toLowerCase();
    final normalizedUnit = unit.trim().toLowerCase();
    int index = _pantryItems.indexWhere(
      (p) =>
          p.name.trim().toLowerCase() == normalizedName &&
          p.unit.trim().toLowerCase() == normalizedUnit,
    );
    if (index != -1) {
      _pantryItems[index].quantity += qty;
    } else {
      String displayName = name.trim();
      if (displayName.isNotEmpty) {
        displayName =
            "${displayName[0].toUpperCase()}${displayName.substring(1)}";
      }
      _pantryItems.add(
        PantryItem(name: displayName, quantity: qty, unit: unit),
      );
    }
    _storage.savePantry(_pantryItems);
    _recalcAvailability();
    
    // Trigger badge se la dispensa cresce
    _badgeService.onPantryItemAdded(_pantryItems.length);
    
    notifyListeners();
  }

  void removePantryItem(int index) {
    if (index >= 0 && index < _pantryItems.length) {
      _pantryItems.removeAt(index);
      _storage.savePantry(_pantryItems);
      _recalcAvailability();
      notifyListeners();
    }
  }

  Future<void> _recalcAvailability() async {
    if (_isCalculating) {
      if (_calculationStartTime != null &&
          DateTime.now().difference(_calculationStartTime!).inSeconds > 30) {
        debugPrint("⚠️ Lock calcolo scaduto, reset forzato");
        _isCalculating = false;
      } else {
        debugPrint("⏭️ Calcolo availability già in corso, skip");
        return;
      }
    }

    if (_dietPlan == null) return;

    _isCalculating = true;
    _calculationStartTime = DateTime.now();

    final planJson = _serializeWeekPlan(currentWeekPlan);

    final payload = {
      'dietData': planJson,
      'days': getDays(),
      'meals': getMeals(),
      'pantryItems': _pantryItems
          .map((p) => {'name': p.name, 'quantity': p.quantity, 'unit': p.unit})
          .toList(),
      'activeSwaps': _activeSwaps.map(
        (key, value) => MapEntry(key, {
          'name': value.name,
          'qty': value.qty,
          'unit': value.unit,
          'swappedIngredients': value.swappedIngredients,
        }),
      ),
    };

    try {
      final newMap = await compute(
        DietCalculator.calculateAvailabilityIsolate,
        payload,
      );
      _availabilityMap = newMap;
      notifyListeners();
    } catch (e) {
      debugPrint("Isolate Calc Error: $e");
    } finally {
      _isCalculating = false;
      _calculationStartTime = null;
    }
  }

  List<String> _extractAllowedFoods() {
    final Set<String> foods = {};
    if (_dietPlan != null) {
      for (final weekPlan in _dietPlan!.weeks) {
        weekPlan.forEach((day, meals) {
          meals.forEach((mealType, dishes) {
            for (var d in dishes) {
              foods.add(d.name);
            }
          });
        });
      }

      _dietPlan!.substitutions.forEach((key, group) {
        for (var opt in group.options) {
          foods.add(opt.name);
        }
      });
    }
    return foods.toList();
  }


  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void toggleTranquilMode() {
    _isTranquilMode = !_isTranquilMode;
    notifyListeners();
  }

  void updateShoppingList(List<String> list) {
    _shoppingList = list;
    _storage.saveShoppingList(list);
    notifyListeners();
  }

  Future<void> setWeeklyBudget(double? budget) async {
    _weeklyBudget = budget;
    await _storage.saveWeeklyBudget(budget);
    notifyListeners();
  }

  Future<void> _loadBudget() async {
    _weeklyBudget = await _storage.loadWeeklyBudget();
  }

  Future<void> swapMeal(String key, ActiveSwap swap) async {
    if (_isViewingHistorical) {
      debugPrint("⏭️ swapMeal skip: dieta storica view-only.");
      return;
    }
    _activeSwaps[key] = swap;
    _storage.saveSwaps(_activeSwaps);
    notifyListeners();
    await _recalcAvailability();
  }

  Future<void> swapDays(String day1, String day2, int weekIndex) async {
    if (_isViewingHistorical) {
      debugPrint("⏭️ swapDays skip: dieta storica view-only.");
      return;
    }
    if (_dietPlan == null) return;
    if (weekIndex < 0 || weekIndex >= _dietPlan!.weeks.length) return;
    final week = _dietPlan!.weeks[weekIndex];
    if (!week.containsKey(day1) || !week.containsKey(day2)) return;

    final temp = week[day1]!;
    week[day1] = week[day2]!;
    week[day2] = temp;

    await _storage.saveDiet(_dietPlan!.toJson());

    final dietJson = _dietPlan!.toJson();
    await _firestore.saveCurrentDiet(
      _sanitize(dietJson['plan'] as Map<String, dynamic>),
      _sanitize(dietJson['substitutions'] as Map<String, dynamic>),
      {},
      weeks: dietJson['weeks'] as List<dynamic>?,
      config: dietJson['config'] as Map<String, dynamic>?,
    );

    _lastSyncedDiet = _deepCopy(dietJson['plan'] as Map<String, dynamic>);
    _lastCloudSave = DateTime.now();
    notifyListeners();
  }

  Future<void> _fetchGlobalConfig() async {
    final data = await _firestore.fetchGlobalConfig();
    if (data != null) {
      if (data['relaxable_foods'] != null) {
        _globalRelaxableFoods = (data['relaxable_foods'] as List).cast<String>().toSet();
      }
      if (data['default_days'] != null) {
        _globalDays = (data['default_days'] as List).cast<String>();
      }
      if (data['default_meals'] != null) {
        _globalMeals = (data['default_meals'] as List).cast<String>();
      }
      notifyListeners();
    }
  }

  Future<void> clearData() async {
    await _storage.clearAll();
    _dietPlan = null;
    _pantryItems = [];
    _activeSwaps = {};
    _shoppingList = [];
    _conversions = {};
    // [SECURITY] Resetta lo stato di sync per evitare che dati del precedente
    // utente influenzino i check di modifica del prossimo login sullo stesso device.
    _lastCloudSave = DateTime.fromMillisecondsSinceEpoch(0);
    _lastSyncedDiet = null;
    _lastSyncedSubstitutions = null;
    _isViewingHistorical = false;
    notifyListeners();
  }

  Map<String, dynamic>? _deepCopy(Map<String, dynamic>? input) {
    if (input == null) return null;
    return jsonDecode(jsonEncode(input));
  }

  /// Rimuove il flag 'consumed' e stati UI per confrontare la struttura pura in fase di sync.
  dynamic _sanitize(dynamic input) {
    if (input is Map) {
      final newMap = <String, dynamic>{};
      input.forEach((key, value) {
        if (key != 'consumed') {
          newMap[key.toString()] = _sanitize(value);
        }
      });
      return newMap;
    } else if (input is List) {
      return input.map((e) => _sanitize(e)).toList();
    }
    return input;
  }

  bool _hasStructuralChanges(
    Map<String, dynamic>? current,
    Map<String, dynamic>? old,
  ) {
    if (current == null && old == null) return false;
    if (current == null || old == null) return true;
    String sCurrent = jsonEncode(_sanitize(current));
    String sOld = jsonEncode(_sanitize(old));
    return sCurrent != sOld;
  }

  Future<void> scheduleMealNotifications() async {
    if (_dietPlan == null) return;

    var status = await Permission.notification.status;

    if (status.isGranted) {
      await _notificationService.scheduleDietNotifications(
        currentWeekPlan,
        days: getDays(),
      );
      debugPrint("🔔 Notifiche pianificate con successo");
    } else {
      _needsNotificationPermissions = true;
      notifyListeners();
    }
  }

  /// Serializza un piano settimanale in JSON puro per Isolate e altri usi.
  Map<String, dynamic> _serializeWeekPlan(
      Map<String, Map<String, List<Dish>>> weekPlan) {
    final Map<String, dynamic> jsonPlan = {};
    weekPlan.forEach((day, meals) {
      final Map<String, dynamic> jsonMeals = {};
      meals.forEach((type, dishes) {
        jsonMeals[type] = dishes.map((d) => d.toJson()).toList();
      });
      jsonPlan[day] = jsonMeals;
    });
    return jsonPlan;
  }

  @override
  void dispose() {
    _repository.dispose();
    _notificationService.dispose();
    debugPrint("🧹 DietProvider disposed");
    super.dispose();
  }
}
