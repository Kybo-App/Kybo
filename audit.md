## STATO FIX

Ordine: severità decrescente, con raggruppamento dei finding correlati. Aggiornato man mano.

### 🔴 Critico
- [x] XP1 / SRV-RW1 / BS1(8b) — economia XP/premi client-autoritativa ✅ 6d07c80 (server), 1eae3bd (client), 71328f6 (rules) — richiede `firebase deploy --only firestore:rules` da parte tua
- [x] F1 (login) + F2 (auth_service) — signup con invito scrive role:'client' negato dalle rules, errore ingoiato ✅ 294f83c

### 🟠 Alto
- [x] SV1 — challenges subcollection senza rules → XP farmabile via replay ✅ chiuso insieme a XP1 (6d07c80/1eae3bd)
- [x] F2 (main.dart) — nessun crash reporting client ✅ 2a56a2e (FlutterError.onError + forwarding centralizzato; collegare un reporter remoto Crashlytics/Sentry resta una decisione prodotto/account dell'utente)

### 🟡 Medio
- [x] SV2 — badge_counters/streak non in whitelist rules → gamification rotta ✅ chiuso insieme a XP1 (6d07c80/1eae3bd), ora gestiti server-side
- [x] SRV-DIET1 — formato dieta incoerente server(chiaro)/client(cifrato) ✅ ac304f4
- [x] SRV-RET1 — purge_user cancella solo `diets`, PII orfana nelle altre subcollection ✅ 739132f
- [x] SRV-2FA-A — two_factor_secret in chiaro su Firestore ✅ 57b2a70 (richiede env `TOTP_ENCRYPTION_KEY` da impostare)
- [x] SRV-GDPR1 + ST1 — nessuna cancellazione/export self-service lato client ✅ 9aade35
- [x] HS1 — delete dieta storica senza conferma ✅ 26ed651
- [x] DS1 — PillButton non si ingrigisce automaticamente ✅ 26ed651
- [x] ST2 — dichiarazione privacy "end-to-end" falsa ✅ 9aade35
- [x] ST3 — reset tutorial scrive chiave obsoleta (v11 vs v13) ✅ 9aade35
- [x] DV1 — empty-state dieta non differenziato per hasNutritionist ✅ 3cbe359
- [x] MC1 — MealCard.onEdit mai invocato (codice morto/irraggiungibile) ✅ 3cbe359
- [x] D2 — syncFromFirebase silenzioso su ogni fallimento ✅ 161f894
- [x] F3 (login, pezzo2) — nessun flusso reset password ✅ 161f894
- [x] F4 — Privacy Policy placeholder senza contenuto reale ✅ 161f894

### 🔵 Basso (spesso ricorrenti, batch)
- [x] Leak `$e` grezzo in UI → ErrorMapper: H2, CH2, meal_suggestions_screen.dart:130, matchmaking_screen.dart (92,116,155,184) ✅ 5d1e97d
- [x] CH3 — attachmentUrl chat: conferma + validazione host prima di aprire ✅ 5d1e97d
- [x] RW2 — redirect_url premio mostrato prima di aprire ✅ 5d1e97d
- [x] MM3 — "Pubblica Richiesta" gated + controller disposati ✅ 5d1e97d
- [x] SRV-SUG1 — leak str(e) in suggestions.py ✅ 9a5eb9b
- [x] SRV-SUG2 — meal_type interpolato grezzo nel prompt Gemini ✅ 9a5eb9b
- [x] SRV-SH1 — POST /shopping-list/share senza auth ✅ 9a5eb9b
- [x] SRV-U2 — assign-user non verifica ruolo nutrizionista ✅ 9a5eb9b
- [x] SRV-ADM1 — audit log PII fire-and-forget ✅ 9a5eb9b
- [x] SRV-2FA-B — nessuna protezione replay TOTP ✅ 9a5eb9b
- [x] SRV-2FA-C — backup code 32-bit (sotto standard) ✅ 9a5eb9b
- [x] Controller dialog non disposati: F6, SL1, DV2, ST5, P1, matchmaking, statistics ✅ c80347a (+5d1e97d per matchmaking)
- [x] P2 — bottone "+" pantry senza gating ✅ c80347a
- [x] DV3 — "Salva" nota senza gating ✅ c80347a
- [x] SS2 — "Crea obiettivo" senza gating ✅ c80347a
- [x] F5 — invite code dialog senza cap/sanitizzazione ✅ c80347a
- [x] H1 — shared list link: errori/non-200 ingoiati in silenzio ✅ ea5235e
- [x] H3 / CH2 — http diretto invece di ApiClient (niente 401→signOut) ✅ ea5235e
- [x] H4 — Navigator pop incoerente (rootNavigator) nel dialog progress upload ✅ ea5235e
- [x] RW1 (rewards_screen) — non usa new_xp_total dal server ✅ chiuso insieme a XP1 (1eae3bd)
- [x] CH4 — sendMessage non atomico (2 scritture separate) ✅ fcab250
- [x] CH1 — reset ridondante unreadCount.client in sendMessage ✅ fcab250
- [x] FS1 — item con decryption_failed renderizzato come dieta normale ✅ fcab250
- [x] FS2 — saveCurrentDiet ingoia errori silenziosamente ✅ fcab250
- [x] D1 — runSmartSyncCheck ritorna valore mai consumato ✅ fcab250
- [x] D3 — consumeMeal senza notifyListeners esplicito ✅ fcab250
- [x] SV4 — meal_alarms in chiaro su SharedPreferences (TODO noto) ✅ c216a58 (migrazione a secure storage)
- [ ] SV3 — trigger badge morti commentati [DEAD] (skip: info, dead code documentato)
- [ ] SRV-NL1 — newsletter/contact POST senza auth (skip: mitigato da rate limit, form pubblici by-design)

### ⚪ Info (fix se banale, altrimenti skip)
- [x] H5 — avatar NetworkImage senza fallback ✅ c216a58
- [x] DV4 — force-consume senza await/error handling ✅ c216a58
- [x] HS2 — nessun feedback di successo su delete ✅ 26ed651
- [x] MR1 — int.parse senza try/catch in meal_reminder_dialog ✅ c216a58
- [x] SRV-GDPR2 — IP non catturato nonostante il claim nel docstring ✅ c216a58
- [x] SRV-MAIN1 — commento stale in main.py:334 ✅ c216a58
- [x] BS2 — tab Sfide bloccata su "Caricamento…" se la generazione fallisce ✅ già risolto come effetto collaterale di XP1 (1eae3bd): loadOrGenerateDailyChallenges ora popola sempre _dailyChallenges col fallback locale anche se il server fallisce
- [ ] F3 (pezzo1), D4, CH5, SS3/MM4, SRV-RET2, SRV-AN1/AN2, SRV-WO1/WO2, SRV-U1, SRV-DIET2 — scelte note/documentate o da solo verificare, nessuna azione (skip: info)

---

📋 AUDIT — Pezzo 1: Bootstrap & routing di autenticazione
File: main.dart, splash_screen.dart, deep_link_service.dart, guard (MaintenanceGuard, EmailVerificationGuard, PasswordGuard)

1. Mappa dei flussi
Trigger	Catena di funzioni	Risultato	Esito
Avvio app	main() → locale, Env.init, Firebase.initializeApp, AppCheck.activate (try/catch), Firestore.settings, TimeHelper.init, runApp(MultiProvider→DietApp)	App + provider pronti	✅
+3s post-avvio	Future.delayed → NotificationService().init() (fire-and-forget)	Notifiche init	⚠️ F3
SplashScreen.initState	_checkAuthAndNavigate → DeepLinkService.init() → getInviteCode	invito → LoginScreen(inviteCode)	✅
idem (no invito)	delay 2s → currentUser? → updateLastLogin + MainScreen / else OnboardingScreen	Navigazione	✅
Wrap di ogni route	MaintenanceGuard stream config/global → maintenance_mode?	Schermata manutenzione / child	⚠️ F1
Wrap di ogni route	EmailVerificationGuard / PasswordGuard (già auditati)	verify/change / child	✅
Deep link a runtime	_listenToLinks → getNavigationTarget → navigationStream	consumato in home_screen.dart:121 → nav tab	✅ consumer presente
Passata B (orphan/dead-end): navigationStream, getSharedListId, getNavigationTarget, getInviteCode, lastUri → tutti consumati (splash + home_screen.dart:121/133/135/154). Nessun orfano in questo pezzo. ✅

2. Findings (per severità)
🟠 F2 — MEDIO · STATE/observability · main.dart:141-143
Cosa succede: runZonedGuarded cattura gli errori async ma li gestisce solo con debugPrint. Non è impostato FlutterError.onError, e non c'è crash reporting client (né Crashlytics né Sentry lato app — il Sentry è solo server).
Impatto: in release ogni crash/eccezione non gestita è invisibile allo sviluppatore → silent failure in produzione su un'app che tratta PII. Non vedi mai gli errori reali degli utenti.
Raccomandazione: aggiungere un reporter (Crashlytics o Sentry Flutter), settare FlutterError.onError e inoltrare l'errore di runZonedGuarded al reporter. (Non applico nulla ora.)

🟡 F1 — BASSO · SECURITY/STATE · main.dart:337-345
Cosa succede: MaintenanceGuard legge config/global, ma le rules permettono la read solo se isSignedIn() (firestore.rules:22). Il guard avvolge anche le schermate pre-login (onboarding/login), dove l'utente non è autenticato → la stream emette permission-denied → snapshot.hasError → ritorna child (fail-open).
Impatto: durante la manutenzione un utente non loggato non vede la schermata di manutenzione e può comunque raggiungere login/onboarding (poi il login fallirebbe contro il backend fermo). Inoltre genera un errore permission-denied a ogni cold-start da sloggato (rumore in monitoring/App Check).
Raccomandazione: valutare se la manutenzione deve valere anche pre-auth; se sì, rendere config/global leggibile pubblicamente (o gestire un canale non protetto). Se il fail-open è voluto, documentarlo. (Scelta di prodotto — decidi tu.)

🔵 F3 — INFO · main.dart:135-139
NotificationService().init() è fire-and-forget dopo 3s senza try/catch locale (un errore finisce nel global handler → vedi F2). Da confermare che init() gestisca internamente utente non loggato / permessi negati. → da verificare nel pezzo Notifiche.

3. Copertura (verificato OK)
✅ Bootstrap completo con guardie try/catch su Firebase/App Check (non-fatale, l'app continua).
✅ Routing splash: invito / autenticato / non autenticato → tutti e 3 i rami navigano.
✅ Sanitizzazione input deep-link: getInviteCode (cap 64), getSharedListId (regex URL-safe + cap 20). Buona difesa su input esterno.
✅ updateLastLogin fire-and-forget volutamente non bloccante (ha try/catch interno).
✅ Deep-link service completamente cablato ai consumer in HomeScreen.
4. Da verificare nei prossimi pezzi (cross-ref)
MainScreen / HomeScreen: gestione cold-start del deep-link condiviso via lastUri (home_screen.dart:133-154).
ChatProvider.initializeChat() (creato in main.dart:122): gestione utente null/permessi.
NotificationService.init() (F3).

📋 AUDIT — Pezzo 2: OnboardingScreen → LoginScreen
File: onboarding_screen.dart, login_screen.dart, auth_service.dart, confronto con client/firestore.rules

1. Mappa dei flussi
Azione utente	Catena	Risultato	Esito
Onboarding: "Ho un Nutrizionista"	_handleInviteCode → dialog → "Avanti" → LoginScreen(inviteCode)	Nav a registrazione	✅
Onboarding: "Utente Indipendente"	_navigateToLogin(isIndependent:true) → LoginScreen	Nav	✅
Onboarding: "Accedi"	_navigateToLogin()	Nav (login)	✅
Login: campo email/pass onChanged	setState → ricalcolo _canSubmit/_emailError	UI aggiornata	✅
Login: ACCEDI	_submit → _auth.signIn → pushReplacement(MainScreen)	Login	✅
Login: REGISTRATI (indipendente)	_submit → signUp(role:'independent') → _ensureUserDoc (rules OK) → MainScreen	Registrazione	✅
Login: REGISTRATI (con invito)	_submit → signUp(role:'client') → _ensureUserDoc → rules NEGANO → catch silenzioso → MainScreen	❌ F1	
Login: Accedi con Google	_googleLogin → signInWithGoogle → MainScreen	Login	✅
Login: toggle registrati/accedi	setState(_isLogin=!_isLogin)	Switch UI	✅
Login: Privacy Policy	_showPrivacyDialog	Dialog placeholder	⚠️ F4
(mancante) Password dimenticata	—	—	❌ F3
2. Findings
🔴 F1 — CRITICO · SECURITY/BROKEN_FLOW · login_screen.dart:101 + auth_service.dart:28 + firestore.rules:42
Cosa succede: in registrazione con codice invito, _submit chiama signUp(role: 'client'). _ensureUserDoc scrive role: 'client' diretto su Firestore, ma la create rule permette solo role in ['independent','user'] → permission denied. L'errore è ingoiato da _ensureUserDoc (solo debugPrint), quindi _submit prosegue e naviga a MainScreen.
Impatto: l'account Firebase Auth viene creato, ma il documento users/{uid} NO. Il flusso primario "cliente con nutrizionista" è rotto in silenzio: l'utente entra nell'app senza profilo, senza ruolo, senza legame col nutrizionista, e il invite_code non viene mai salvato. Nessuna Cloud Function onCreate fa da rete (verificato: non esiste functions/).
Nota: pre-esistente, non introdotto dalle mie modifiche. C'è anche un'incoerenza di naming ruoli: l'app usa 'client', il server usa 'user', le rules ammettono 'user'.
Raccomandazione: allineare il ruolo — o signUp passa 'user' (come il server), oppure aggiungere 'client' alla whitelist delle rules — e decidere UNA convenzione. (Fix dopo, su tua conferma.)

🟠 F2 — ALTO · SECURITY/STATE (silent failure) · auth_service.dart:40-42
Cosa succede: _ensureUserDoc cattura ogni errore e fa solo debugPrint. Il chiamante (signUp/signInWithGoogle) non sa mai se il doc è stato creato.
Impatto: è il meccanismo che rende F1 invisibile, ma vale in generale: qualsiasi fallimento di creazione doc (rules, rete) → l'utente prosegue a MainScreen senza profilo. "Silent failure = errore peggiore".
Raccomandazione: propagare l'errore (o ritornare un bool/verificare l'esistenza del doc dopo la creazione) e gestirlo nella UI di login; non navigare se il profilo non è pronto.

🟡 F3 — MEDIO · BROKEN_FLOW (flusso mancante) · login_screen.dart
Cosa succede: non esiste nessun flusso di reset password in tutto client/lib (grep sendPasswordResetEmail → 0). Il login ha email/password/Google/registrati/privacy, ma nessun "Password dimenticata?".
Impatto: un utente email/password che dimentica la password è bloccato fuori senza recupero in-app.
Raccomandazione: aggiungere "Password dimenticata?" → FirebaseAuth.sendPasswordResetEmail.

🟡 F4 — MEDIO · compliance / risultato non pratico · login_screen.dart:127-159
Cosa succede: il link "accetti la Privacy Policy e i Termini di Servizio" apre un dialog con testo segnaposto ("…secondo le normative vigenti"), senza policy reale né link ai documenti.
Impatto: app di salute in UE (GDPR/dati sanitari): dichiarare l'accettazione di documenti che non esistono è un rischio legale, e il tap "non porta a niente di pratico".
Raccomandazione: collegare Privacy/Termini reali (URL o testo integrale).

🔵 F5 — BASSO · SECURITY (validazione input) · onboarding_screen.dart:46-54
Il dialog invito passa controller.text con solo isNotEmpty, senza il cap/sanitizzazione presente nel path deep-link (getInviteCode cap 64). Incoerente. (Secondario: comunque il doc fallisce per F1.)

🔵 F6 — INFO · leak risorsa · onboarding_screen.dart:19
TextEditingController creato in _handleInviteCode e mai dispose(). Micro-leak (scope dialog, StatelessWidget).

3. Copertura (verificato OK)
✅ Gating submit _canSubmit: email regex + password (login) / policy completa (registrazione).
✅ PillButton correttamente grigiato con colori muted espliciti quando !_canSubmit (evitata la trappola dell'auto-grey).
✅ Errore email inline solo dopo digitazione; checklist password live in registrazione.
✅ Google e submit disabilitati durante _isLoading; if (mounted) dopo ogni await.
✅ Errori mostrati via ErrorMapper.toUserMessage (nessun leak grezzo di eccezioni).
✅ Registrazione indipendente e login e Google: flussi completi fino a MainScreen.
4. Cross-ref prossimi pezzi
MainScreen/HomeScreen: come si comporta con un utente senza doc users/{uid} (conseguenza di F1/F2) — potenziale crash/schermata rotta.
signInWithGoogle: _ensureUserDoc con ruolo 'independent' (rules OK) ma stessa fragilità silent (F2).

📋 AUDIT — Pezzo 3: MainScreen / HomeScreen
File: home_screen.dart (nav, drawer, upload dieta, scan scontrino, export PDF, deep-link lista condivisa, logout)

1. Mappa dei flussi (sintesi)
Azione utente	Catena	Risultato	Esito
Nav bar / sidebar (Dispensa/Piano/Lista)	setState(_currentIndex) → _buildBody	Switch vista	✅
Voci drawer (Chat, Cronologia, Traguardi, Statistiche, Suggerimenti, Premi, PDF, Impostazioni, Coach)	Navigator.push(...)	Nav a schermata	✅ (tutte cablate)
AppBar: menu / swap giorno / modalità relax	openDrawer / _showDaySwapSheet / provider.toggleTranquilMode	Drawer / sheet / toggle	✅
Swap giorni (conferma)	provider.swapDays + snackbar	Scambio + feedback	✅
Selettore settimana	provider.setWeek + setState	Cambio settimana	✅
Avatar → carica foto	_pickAndUploadProfilePhoto → POST /profile/upload-photo (token)	Foto + snackbar	⚠️ H2/H3
Carica Dieta PDF	_uploadDiet → provider.uploadDiet (dialog progress)	Dieta + success/error	⚠️ H4
Scansiona scontrino	_scanReceipt → provider.scanReceipt	"Aggiunti N prodotti"	✅
Esporta PDF	_exportDietPdf → GET /export-diet-pdf (token) → Share	Condivisione file	⚠️ H2/H3
Deep-link lista condivisa	_loadAndShowSharedList → GET /shopping-list/share/{id} → dialog → _mergeSharedItems	Merge + snackbar	⚠️ H1
Logout	clearData + clearChat + signOut + pushReplacement(Login)	Uscita pulita	✅
2. Findings
🟡 H1 — MEDIO · STATE (silent failure) · home_screen.dart:162-176
_loadAndShowSharedList fa http.get e ha catch (_) {} totalmente muto; inoltre gestisce solo statusCode == 200. Se il link condiviso è scaduto/invalido (404), il server è down, o la rete cade → non succede nulla: l'utente apre un link "lista condivisa", atterra sulla tab Lista e non vede né la lista né un errore.
Raccomandazione: mostrare un feedback su fallimento/non-200 ("Lista non trovata o scaduta").

🔵 H2 — BASSO · SECURITY (info leak) · home_screen.dart:2197 e :2361
_pickAndUploadProfilePhoto mostra 'Errore: $e' e _exportDietPdf mostra 'Errore: ${e.toString()}' → eccezione grezza in UI, incoerente col resto che usa ErrorMapper.toUserMessage. Possibile esposizione di dettagli interni.
Raccomandazione: usare ErrorMapper.toUserMessage(e) anche qui.

🔵 H3 — BASSO · robustezza/SECURITY · home_screen.dart:2168, 2336, 165
Tre flussi (upload-photo, export-diet-pdf, shopping-list/share) usano http diretto invece di ApiClient. Perdono la gestione centralizzata 401 → signOut e il retry di rete: se il token è scaduto, questi flussi mostrano un errore generico invece di forzare il re-login.
Raccomandazione: instradare anche questi su ApiClient (o replicare il check 401).

🔵 H4 — BASSO (latente) · BROKEN_FLOW · home_screen.dart:2297 vs :2309
Il dialog di progresso upload è canPop:false + barrierDismissible:false. Su successo viene chiuso con Navigator.of(context).pop() (non-root), su errore con Navigator.of(context, rootNavigator:true).pop(). showDialog usa di default il root navigator: con un solo Navigator (caso attuale) i due coincidono e funziona, ma è incoerente — se in futuro si introducesse un Navigator annidato, il pop di successo mancherebbe il dialog e l'utente resterebbe bloccato sul progress non-chiudibile.
Raccomandazione: usare rootNavigator: true in entrambi i rami.

⚪ H5 — INFO · home_screen.dart:1713-1717
L'avatar usa NetworkImage(photoUrl) senza onError/fallback. Il photo_url è un signed URL a scadenza 7 giorni (server): una volta scaduto → immagine rotta silenziosa (nessun ritorno all'iniziale).

3. Nota su F1/F2 (dai pezzi precedenti)
Buona notizia: un utente senza doc users/{uid} (conseguenza di F1/F2) non crasha qui — _buildDrawer/_startShowcase fanno tutti il check snapshot.data!.exists e degradano alla vista "indipendente" (avatar "Ospite", drawer con "Carica Dieta" + "Trova Coach"). Cattiva notizia: conferma che il legame col nutrizionista viene perso in silenzio (il cliente diventa di fatto un utente indipendente slegato).

4. Copertura (verificato OK)
✅ Tutte le ~12 voci del drawer/sidebar sono cablate a una Navigator.push reale (nessun bottone morto).
✅ Token Firebase allegato su tutte le chiamate autenticate (upload-photo, export-diet-pdf); shared-list è pubblico by-design.
✅ Logout sicuro: clearData + clearChat (pulizia PII in memoria) prima di signOut.
✅ Upload dieta: dialog progress con % + success/error via ErrorMapper; file picker ristretto a pdf / immagini / jpg,jpeg,png.
✅ Merge lista condivisa: parsing regex sicuro, dedup, snackbar risultato.
✅ Avviso jailbreak + permessi notifiche: entrambi con azioni concrete.
✅ if (mounted)/context.mounted dopo gli await nei punti critici.
5. Cross-ref (prossimi pezzi)
DietProvider (grande dipendenza): syncFromFirebase (comportamento con doc mancante), uploadDiet, scanReceipt, updateShoppingList, swapDays, getDays, loadFromCache. → candidato Pezzo 4.
ChatProvider: unreadCount, nutritionistName, clearChat, initializeChat.

📋 AUDIT — Pezzo 4: DietProvider + DietRepository + EncryptionService
File: providers/diet_provider.dart, repositories/diet_repository.dart, services/encryption_service.dart (+ firestore_service.dart per il write-path)

1. Mappa dei flussi (dati)
Trigger	Catena	Risultato	Esito
Avvio → loadFromCache	storage locale → DietPlan + _fetchGlobalConfig	Dieta da cache	✅
Avvio → syncFromFirebase	Firestore diets/current → decrypt → merge consumi → save cache	Dieta cloud	⚠️ D2
Consuma pasto	consumeMeal → pantry decrement + XP + sfide + _recalcAvailability	Check + XP	⚠️ D3
Modifica pasto	updateDietMeal → save + _triggerSmartSyncCheck + recalc	Aggiornamento + notify	✅
Swap giorni/pasti	swapDays/swapMeal → save + saveCurrentDiet (cifrato)	Scambio + sync	✅
Upload dieta	uploadDiet → repo → /upload-diet (UploadClient, token) → parse	Nuova dieta	✅
Scan scontrino	scanReceipt → /scan-receipt (token, allowed_foods) → pantry	+N prodotti	✅
Ripristina storico	loadHistoricalDiet → cache + push current (cifrato)	Dieta ripristinata	✅
Sync manuale	runSmartSyncCheck → ritorna stringhe di stato	valore ignorato	⚠️ D1
Logout	clearData → wipe locale + reset stato sync	Pulizia	✅
2. Findings
🟡 D2 — MEDIO · STATE (silent failure) · diet_provider.dart:483-486, 586-588
syncFromFirebase è muto su ogni fallimento: se la decifratura dei campi cloud fallisce → return con solo debugPrint (483-486); qualunque altro errore (rete, permessi) → catch con debugPrint "Sync Cloud fallito" (586). L'utente non riceve alcuna indicazione: resta con la cache locale (potenzialmente stale) credendo di essere sincronizzato. Su un'app dieta significa non vedere gli aggiornamenti del nutrizionista, o modifiche che non propagano tra device.
Probabilità: bassa per la decifratura (chiave da UID stabile), più alta per rete/permessi.
Raccomandazione: esporre almeno uno stato "sync fallito / offline" osservabile (banner o indicatore), non solo log.

🔵 D1 — BASSO · NO_RETURN (valore mai consumato) · diet_provider.dart:88-161
runSmartSyncCheck calcola e ritorna stringhe di stato ricche ("✅ Nessuna modifica", "☁️ Modifiche sincronizzate", "❌ Errore Sync: $e"…), ma l'unico chiamante (_triggerSmartSyncCheck, riga 177) scarta il valore. Nessuna UI mostra questi messaggi (grep confermato). → Lavoro prodotto e buttato; e il ramo "❌ Errore Sync: $e" (159), pensato per l'utente, non raggiunge mai la UI.
Raccomandazione: o cablare il ritorno a un feedback reale (es. pull-to-refresh sync), o semplificare la firma a Future<void>.

🔵 D3 — BASSO · STATE (refresh UI condizionato) · diet_provider.dart:771-877 + 1051-1061
consumeMeal non chiama notifyListeners() esplicito a fine metodo: si affida a _recalcAvailability per notificare. Ma _recalcAvailability fa early-return senza notify se un altro calcolo è già in corso (lock, riga 1058). In quel caso il pasto risulta consumato nei dati ma la spunta potrebbe non aggiornarsi finché non arriva un altro rebuild.
Raccomandazione: notifyListeners() esplicito al termine di consumeMeal.

⚪ D4 — INFO · persistenza locale-only · diet_provider.dart:1013-1049, 1135-1139
Dispensa e lista spesa sono salvate solo in locale (StorageService), non su Firestore. Cambiando device / reinstallando l'app si perdono. Probabilmente by-design (device-specific), ma da confermare che sia voluto.

3. Cifratura (riconferma, non nuovo finding)
✅ Il write-path cifra plan/substitutions/activeSwaps/weeks (firestore_service.dart), con encrypted:true e cancellazione dei fossili legacy in chiaro.
⚠️ Come già documentato nel file: è offuscamento, non cifratura forte (chiave derivata dal solo UID, non segreto). La protezione reale a riposo = Firestore rules + at-rest di Google. Già tracciato in TODO.md ("cifratura server-side"). Nessuna azione nuova richiesta — è una scelta nota e commentata onestamente.
4. Copertura (verificato OK)
✅ clearData (logout) azzera cache locale e stato di sync (_lastSyncedDiet, _lastCloudSave) → niente contaminazione tra utenti sullo stesso device.
✅ Scritture dieta vanno sul path dell'owner (users/{uid}/diets/...) → conformi alle rules; contenuto PII cifrato.
✅ _isViewingHistorical inibisce scritture/sync in vista storica (evita di sovrascrivere la current) — logica difensiva coerente in tutti i mutator.
✅ Calcolo disponibilità su Isolate (compute) con lock + timeout 30s.
✅ Upload/scan passano da UploadClient/ApiClient (token allegato); _sanitize rimuove campi volatili prima di diff/salvataggio.
5. Cross-ref (prossimi pezzi)
ChatProvider (initializeChat, unreadCount, clearChat, invio messaggi, typing) + ChatScreen — flusso realtime con scritture Firestore dirette → da confrontare con le chat rules. Buon candidato Pezzo 5.
StorageService/FirestoreService restanti metodi (letture storico) se vuoi approfondire il data-layer.

📋 AUDIT — Pezzo 5: Chat (ChatProvider + ChatScreen)
File: providers/chat_provider.dart, screens/chat_screen.dart — confrontati con le chat rules (firestore.rules:146-208)

1. Mappa dei flussi
Azione utente	Catena	Risultato	Esito
Apri chat	initState → markAsRead → reset unreadCount.client + read:true	Badge azzerato	✅
Scrivi (onChanged)	notifyTyping → typing.client (throttle 1/burst + 3s)	Indicatore "sta scrivendo"	✅
Invia messaggio	_sendMessage → (uploadAttachment?) → sendMessage (add msg + update chat)	Messaggio + badge	⚠️ CH1/CH4
Allega file	_pickFile (jpg/png/pdf) → preview → uploadAttachment (/chat/upload-attachment, token)	Allegato	⚠️ CH2
Tap allegato	_openUrl → launchUrl(externalApplication)	Apre URL esterno	⚠️ CH3
Quick-reply chip	set _messageController.text	Prefill campo	✅
Indietro	Navigator.pop (+ clearTyping in dispose)	Uscita	✅
Conformità rules (verificata): tutte le scritture passano — _ensureChatDocument/sendMessage usano participants.clientId == uid (create/update OK), markAsRead sui messaggi tocca solo ['read'] (combacia con affectsOnly(['read'])), i messaggi hanno senderId == uid. ✅ Nessuna scrittura verrebbe rifiutata.

2. Findings
🟡 CH5 — MEDIO · privacy/consistenza · chat_provider.dart (write path) + firestore.rules
I messaggi di chat e i metadati allegati sono salvati in chiaro su Firestore (nessuna cifratura app-level), a differenza della dieta (offuscata). Contenuto potenzialmente sanitario (sintomi, condizioni). Protezione reale = rules participant-only + at-rest di Google.
Impatto: chi ottiene un dump/accesso admin Firestore legge tutte le conversazioni in chiaro. Incoerente con la scelta (per quanto debole) fatta sulla dieta.
Raccomandazione: decisione consapevole — o accettare (rules+at-rest) e documentarlo come per la dieta, o pianificare cifratura server-side insieme al TODO "cifratura dieta". (Nessuna fix ora.)

🔵 CH3 — BASSO · SECURITY (URL non validato) · chat_screen.dart:452-457, 551, 594
_openUrl fa launchUrl(..., externalApplication) sull'attachmentUrl del messaggio senza validare scheme/host. Per i messaggi ricevuti, l'URL è scritto da chi crea il messaggio (il professionista): un account professionista compromesso/malevolo potrebbe inviare un allegato "immagine/PDF" con un link di phishing che il cliente apre esternamente.
Raccomandazione: validare che l'host sia il dominio Firebase Storage atteso (o mostrare l'URL prima di aprire).

🔵 CH2 — BASSO · SECURITY (info leak) + robustezza · chat_screen.dart:111, chat_provider.dart:290-324
_sendMessage mostra 'Errore invio: $e' (eccezione grezza in UI). Inoltre uploadAttachment usa http diretto (no ApiClient) → niente 401→signOut; nessun cap dimensione file lato client prima dell'upload (si affida al ContentSizeLimitMiddleware server).
Raccomandazione: ErrorMapper per il messaggio; instradare su ApiClient; opzionale cap dimensione client.

🔵 CH4 — BASSO · atomicità · chat_provider.dart:369 vs :380
sendMessage fa due scritture separate (add messaggio, poi update doc chat con unreadCount.nutritionist++). Se la seconda fallisce, il messaggio esiste ma il contatore/anteprima del nutrizionista non si aggiorna → possibile messaggio "silenzioso" per il destinatario. Non atomico (no batch/transaction).

⚪ CH1 — INFO · chat_provider.dart:391-392
sendMessage resetta unreadCount.client: 0 a ogni invio. Ridondante (la markAsRead in apertura chat l'ha già azzerato) e concettualmente "l'invio marca come letti i messaggi altrui". Innocuo perché la chat è già aperta, ma vale la pena toglierlo.

3. Copertura (verificato OK — questo pezzo è messo bene)
✅ Tutti e 4 gli stati nello stream messaggi: loading (SkeletonChatBubbles), errore ("Errore caricamento messaggi"), empty gamificato (icona + quick-reply), dati. Esemplare.
✅ Scritture chat 100% conformi alle rules (participant + senderId==uid + affectsOnly(['read'])).
✅ clearChat (logout) cancella subscription, campi PII e cache locale per-uid → niente leak cross-utente.
✅ Typing indicator throttlato (1 scrittura/burst + reset a 3s) → non martella Firestore.
✅ Image.network allegati con errorBuilder e loadingBuilder (a differenza dell'avatar in H5).
✅ Allegati ristretti a jpg/png/pdf; token allegato sull'upload; badge "✓/✓✓" letti coerente.
✅ Utente senza parent_id/senza doc → initializeChat esce pulito (nessun crash; la voce Chat non compare nel drawer).
4. Cross-ref
Endpoint server /chat/upload-attachment (validazione file/size) — pezzo server, se farai l'audit backend.
markAsRead marca letti solo i messaggi senderType in ['nutritionist','admin'] — coerente.

📋 AUDIT — Pezzo 6: PantryView + ShoppingListView
File: screens/pantry_view.dart, screens/shopping_list_view.dart

1. Mappa dei flussi
Azione utente	Catena	Risultato	Esito
Dispensa – Scansiona scontrino (FAB)	onScanTap → home _scanReceipt	+N prodotti	✅
Dispensa – Ricette AI	Navigator.push(MealSuggestionsScreen)	Nav	✅
Dispensa – Aggiungi (nome/qtà/unità)	_handleAdd → onAddManual → provider	Item aggiunto	⚠️ P2
Dispensa – Swipe elimina	Dismissible → onRemove(index)	Rimozione	✅
Lista – Genera da dieta	_showImportDialog → seleziona pasti → _generateListFromSelection → onUpdateList + snackbar	Lista generata	✅
Lista – Spunta item	onChanged → onUpdateList (prefix OK_)	Toggle	✅
Lista – Sposta nel Frigo	gated hasCheckedItems → _moveCheckedToPantry → onAddToPantry	+N nel frigo	✅
Lista – Budget	_showBudgetDialog → setWeeklyBudget	Budget salvato	⚠️ SL1
Lista – Condividi testo	_shareList → Share.share	Condivisione	✅
Lista – Condividi link	_shareLinkList → POST /shopping-list/share (ApiClient) → Share.share	Link 7gg	✅
Lista – Raggruppa/Swipe/Vista	setState / onUpdateList	UI	✅
2. Findings
🔵 P1 — BASSO · leak risorsa · pantry_view.dart:26-40
_PantryViewState dichiara _nameController e _qtyController ma non ha un dispose() → i due TextEditingController non vengono mai rilasciati. Memory leak ogni volta che la tab Dispensa viene ricreata.
Raccomandazione: aggiungere dispose() che chiama _nameController.dispose() + _qtyController.dispose().

🔵 P2 — BASSO · STATE (no feedback) · pantry_view.dart:31-40, 215-222
Il bottone "+" (aggiungi cibo) chiama _handleAdd, che non fa nulla in silenzio se il nome è vuoto (if (_nameController.text.isNotEmpty)), ma il bottone non è disabilitato: l'utente preme e non succede niente, senza spiegazione.
Raccomandazione: disabilitare/grigiare il "+" finché il nome è vuoto, o mostrare un hint.

⚪ SL1 — INFO · leak risorsa · shopping_list_view.dart:236
_showBudgetDialog crea un TextEditingController locale mai dispose() (scope dialog). Micro-leak, come nel dialog invito onboarding (F6). Pattern ricorrente.

3. Copertura (verificato OK — sezioni ben costruite)
✅ ShoppingListView è un modello di error handling: _shareLinkList usa ApiClient, snackbar di loading, hideCurrentSnackBar a fine, ApiException.message + fallback pulito ("Impossibile generare il link. Controlla la connessione."). Nessun leak di $e — contrario al pattern di home_screen.
✅ Empty state Lista = "positivo" gamificato ("Tutto in dispensa! 🎉" + CTA "Genera da dieta").
✅ "Sposta nel Frigo" correttamente gated e grigiato (hasCheckedItems ? primary : grey) — evitata la trappola PillButton.
✅ _generateListFromSelection in try/catch con messaggio pulito ("Errore creazione lista."), sottrae la dispensa, aggrega per pasto, ordina.
✅ Parsing quantità robusto via DietCalculator.parseQty/parseUnit; categorizzazione merceologica ampia.
✅ Nessuna scrittura Firestore diretta qui (tutto passa dal DietProvider/ApiClient) → nessun rischio rules in questo pezzo.
4. Nota di sicurezza
_shareLinkList carica la lista (nomi di cibi — non PII sensibile) su un endpoint che genera un link pubblico a 7 giorni. È la funzione voluta; l'utente sceglie di condividere. La sanitizzazione dell'id in lettura è già stata verificata nel Pezzo 3 (getSharedListId, cap 20 + regex). ✅

📋 AUDIT — Pezzo 7: DietView (tab "Piano")
File: screens/diet_view.dart (+ callback verso MealCard)

1. Mappa dei flussi
Azione utente	Catena	Risultato	Esito
Selettore porzioni ×1/2/4/6	setState(_portionMultiplier)	Ricalcolo grammature	✅
Pull-to-refresh	provider.refreshAvailability	Ricalcolo disponibilità	✅
Consuma pasto (MealCard)	_handleConsume → consumeMeal (+dialog conversione/forza)	Consumato + XP	✅ (ottimo)
Sostituisci (swap)	_showSwapDialog → swapMeal / "Nessuna Sostituzione"	Swap	✅
Modifica piatto	onEdit → updateDietMeal	Aggiornamento + sync	⚠️ DV3
Nota/diario pasto	_showNoteDialog → saveMealNote	Nota salvata	⚠️ DV2
Empty "nessuna dieta" → Contatta nutrizionista	Navigator.push(ChatScreen)	Chat	⚠️ DV1
2. Findings
🟡 DV1 — MEDIO · BROKEN_FLOW/UX · diet_view.dart:62-108
Lo stato "nessuna dieta" è cablato sul caso "utente con nutrizionista": testo "Il tuo nutrizionista non ti ha ancora caricato un piano" + CTA "Contatta il nutrizionista" → ChatScreen. Ma questo stato appare anche agli utenti indipendenti (che caricano la dieta da soli e non hanno un nutrizionista). Per loro:

il messaggio è sbagliato (dovrebbe invitare a "Carica la tua dieta");
la CTA porta a una chat non funzionante — con parent_id nullo, initializeChat esce, _currentChatId resta null e sendMessage fa return silenzioso (Pezzo 5): l'utente scrive e "invia" senza che nulla parta. Vicolo cieco.
Raccomandazione: differenziare l'empty in base a hasNutritionist (independent → CTA "Carica dieta"/upload; con nutri → "Contatta").
🔵 DV2 — BASSO · leak risorsa · diet_view.dart:284, 448
_showConversionDialog (controller) e _showNoteDialog (noteController) creano TextEditingController mai dispose() (scope dialog). Pattern ricorrente (F6, SL1, DV2).

🔵 DV3 — BASSO · STATE (no feedback) + prodotto · diet_view.dart:159-160, 529
Due micro-punti:

Nota: il "Salva" non fa nulla in silenzio se la nota è vuota (if (...isNotEmpty)), bottone non disabilitato → tap senza effetto/feedback (come P2).
Modifica piatto (onEdit → updateDietMeal): il client può rinominare/riquantificare i piatti della dieta prescritta (il doc è owner-writable). Tecnicamente lecito e sincronizzato, ma da confermare che sia voluto che il cliente modifichi liberamente la dieta del nutrizionista.
⚪ DV4 — INFO · diet_view.dart:262
Il ramo "Sì, consuma" (force) chiama provider.consumeMeal(..., force:true) senza await né gestione errori → eventuali errori nel force-consume vengono ingoiati e non mostra lo snackbar "Pasto consumato".

3. Copertura (verificato OK — sezione robusta)
✅ _handleConsume è un modello di gestione errori "cosa+perché+azione": UnitMismatchException → dialog di conversione unità (flusso di recupero), IngredientException → conferma "consuma comunque", altrimenti ErrorMapper. Tre percorsi, tutti con sbocco.
✅ Stati multipli gestiti: loading (spinner), nessuna dieta (con CTA), "Riposo" (giorno senza piano).
✅ Nota diario: maxLength: 500 con contatore nativo + selettore mood.
✅ Swap: caso "nessuna sostituzione" gestito con dialog dedicato (non un crash/vuoto).
✅ Tutti i callback MealCard (onEat/onSwap/onEdit/onNote) → azioni reali del provider.
✅ Scritture solo via DietProvider (già verificato conforme alle rules nel Pezzo 4).
4. Cross-ref
MealCard (widgets/meal_card.dart): è dove vivono i bottoni fisici mangia/swap/modifica e il rendering grammature/relax. Se vuoi scendere di un livello, è il prossimo naturale.

📋 AUDIT — Pezzo 8a: SettingsScreen + RewardsScreen
1. Mappa dei flussi
Azione utente	Catena	Risultato	Esito
Settings – Cambia password	Navigator.push(ChangePasswordScreen)	Nav	✅
Settings – Gestisci allarmi / Budget / Supermercati / Timer / Dark / Privacy	dialog/nav/provider	Config	⚠️ ST2/ST5
Settings – Riavvia Tutorial	_resetTutorial → setBool('seen_tutorial_v11', false) + pop	niente	❌ ST3
Rewards – carica catalogo/storico	_loadCatalog/_loadClaims → GET /rewards/catalog,/my-claims	Liste	✅
Rewards – Riscatta premio	check XP (client) → conferma → POST /rewards/claim/{id} → spendXp local	Premio + XP−	⚠️ RW1
Rewards – Apri link premio	launchUrl(redirect_url, external)	URL esterno	⚠️ RW2
2. Findings
🟡 ST3 — MEDIO · DEAD_END (azione senza effetto) · settings_screen.dart:617
"Riavvia Tutorial" fa prefs.setBool('seen_tutorial_v11', false) e chiude la schermata. Ma il gate reale del tutorial legge seen_tutorial_v13 (home_screen.dart:426). La chiave v11 è obsoleta e non letta da nessuno → il tutorial non riparte mai. L'utente preme, la schermata si chiude, e non succede nulla.
Raccomandazione: azzerare seen_tutorial_v13 (allineare la versione).

🟡 ST2 — MEDIO · falsa dichiarazione privacy · settings_screen.dart:596-598 (+ login F4)
Il dialog Privacy afferma: "I tuoi dati sono crittografati end-to-end". È falso: la "cifratura" dieta è offuscamento con chiave derivata dall'UID (documentato onestamente in encryption_service.dart), e la chat è in chiaro (Pezzo 5, CH5). Dichiarare E2E che non esiste è un rischio legale/di fiducia su un'app sanitaria.
Raccomandazione: correggere il testo (rimuovere "end-to-end") e collegare una policy reale.

🟡 ST1 — MEDIO · BROKEN_FLOW (flusso GDPR mancante) · settings_screen.dart
Non esiste alcuna voce per cancellare l'account o esportare i propri dati nell'app client. Il backend ha endpoint GDPR (gdpr.py) e l'admin ha la dashboard, ma l'utente finale non può auto-servirsi del diritto di cancellazione/portabilità. Gap di compliance per un'app UE con dati sanitari.
Raccomandazione: aggiungere "Elimina account" + "Scarica i miei dati" cablati agli endpoint GDPR.

🔵 RW1 — BASSO · NO_RETURN/consistenza · rewards_screen.dart:207-214
Dopo il claim, il server ritorna new_xp_total (valore autorevole), ma il client lo usa solo come null-check e poi decrementa localmente (xpService.spendXp(xpCost)) invece di allinearsi al valore server. Eventuale drift XP client↔server si perpetua fino al prossimo reload.
Raccomandazione: impostare l'XP locale a new_xp_total (usare il valore, non solo controllarlo).

🔵 RW2 — BASSO · SECURITY (URL esterno) · rewards_screen.dart:271
redirect_url del premio aperto con launchUrl(externalApplication) senza validazione host. È admin-sourced (più fidato della chat), ma un account admin compromesso potrebbe iniettare un link di phishing. Come CH3, ma rischio minore.

🔵 ST5 — BASSO · leak risorsa · settings_screen.dart:463
_showBudgetDialog controller mai dispose() (pattern ricorrente F6/SL1/DV2).

3. Nota di sicurezza (dipende dal server — da verificare in audit backend)
Il riscatto premi fa il check XP lato client solo per UX (totalXp < xpCost, riga 97). La sicurezza reale dipende interamente dall'endpoint POST /rewards/claim/{id}: deve verificare il saldo XP, decrementarlo atomicamente, controllare/decrementare lo stock, e prevenire doppi claim. Dal lato client è impostato correttamente (enforcement delegato al server); va confermato che il server lo faccia davvero.

4. Copertura (verificato OK)
✅ RewardsScreen è esemplare: tutti e 4 gli stati in entrambe le tab (skeleton / KyboErrorView+retry / empty / dati), conferma con saldo-dopo, messaggio XP insufficienti, AbsorbPointer anti-doppio-claim, error handling pulito (ApiException.message + fallback "Errore di connessione", nessun leak).
✅ Card premio con onTap: null quando non affordabile/esaurito/in-claim (gating corretto), Image.network con errorBuilder.
✅ Settings: dark mode, budget, supermercati (draft+salva), allarmi, timer — tutte con effetto concreto e persistenza.

📋 AUDIT — Pezzo 8b+8c: Schermate secondarie rimanenti
File: meal_suggestions_screen.dart, matchmaking_screen.dart, history_screen.dart, statistics_screen.dart, badges_screen.dart

Findings principali
🟠 BS1 — ALTO · SECURITY (integrità economia XP) · firestore.rules:47 ↔ rewards_screen.dart / badges_screen.dart
Le Firestore rules permettono all'owner di scrivere direttamente xp_total, xp_today, unlocked_badges sul proprio doc (whitelist update, riga 47). Ma gli XP gattano il riscatto premi (RewardsScreen, Pezzo 8a). Se l'endpoint server POST /rewards/claim si fida del valore xp_total scritto dal client, un utente malevolo può gonfiare gli XP via SDK Firestore e riscattare premi gratis.
Impatto: economia gamification aggirabile → premi reali ottenuti senza merito.
Da verificare nel server: il claim deve ricalcolare/tracciare gli XP autorevolmente lato server (o da xp_history non-client-writable), non leggere il campo xp_total client-writable. → Priorità per l'audit backend.

🟡 HS1 — MEDIO · azione distruttiva senza conferma · history_screen.dart:101-113
Il cestino su una dieta storica chiama firestore.deleteDiet(diet['id']) immediatamente al tap, senza dialog di conferma. Cancellazione permanente (rules: delete definitivo). Un tap accidentale = storico dieta perso. Incoerente: il Ripristina ha la conferma, il Elimina no.
Raccomandazione: aggiungere un dialog di conferma (come per il ripristino).

🔵 MM3 — BASSO · STATE (no validazione) · matchmaking_screen.dart:75-98
"Pubblica Richiesta" chiama createRequest(type, goalCtrl.text, notesCtrl.text) senza verificare che l'obiettivo sia non vuoto e senza gating del bottone → si può pubblicare una richiesta vuota.

🔵 Leak $e grezzo in UI (ricorrente) · vari
meal_suggestions_screen.dart:130 → 'Errore imprevisto: $e'
matchmaking_screen.dart:92, 116, 155, 184 → "Errore: $e" / "Errore: ${provider.error}"
Eccezioni grezze mostrate all'utente (dovrebbero passare da ErrorMapper). Basso ma diffuso.
🔵 Controller di dialog non disposti (ricorrente) · vari
matchmaking (goalCtrl/notesCtrl), statistics (_showAddGoalDialog: title/target). Micro-leak, come F6/SL1/DV2/ST5.

⚪ Note (INFO)
HS2: delete dieta senza feedback di successo (solo l'errore ha snackbar).
SS2: "Crea obiettivo" no-op silenzioso se titolo vuoto (pattern P2/DV3).
SS3/MM4 (privacy): weight_history (peso) e le note matchmaking (possibili intolleranze/dati sanitari) sono in chiaro su Firestore — coerente con CH5 (chat). Le note matchmaking sono inoltre visibili ai professionisti che sfogliano le richieste (opt-in).
BS2: la tab "Sfide" resta su "Caricamento sfide…" a oltranza se la generazione fallisce (nessuno stato d'errore).
Copertura (verificato OK — queste schermate sono in gran parte solide)
✅ MealSuggestionsScreen: 4 stati esemplari (loading con testo dinamico "Gemini AI sta elaborando", errore, empty, dati), ApiException/NetworkException/generico distinti, refresh gated su _loading.
✅ StatisticsScreen: stato d'errore con retry (fix dello spinner infinito), validazione peso 20–300 kg, subscription e controller disposti, flusso permessi Health con grant/deny gestiti.
✅ MatchmakingScreen: 4 stati, conferma sulla cancellazione, stati offerta (pending/accepted/rejected/withdrawn), "Accetta" solo su pending+open, note maxLength 500+contatore.
✅ HistoryScreen: 4 stati con ErrorMapper, conferma sul ripristino, letture/cancellazioni owner-scoped (conformi rules).
✅ BadgesScreen: pura visualizzazione (tab Badge/Sfide/XP), nessuna scrittura diretta, empty states curati, badge segreti mascherati.

📋 AUDIT — Pezzo 9: Widget (MealCard, MealReminderDialog, PillButton)
Findings
🟡 MC1 — MEDIO · ORPHAN (callback mai invocato) · meal_card.dart:20,38
MealCard dichiara e richiede onEdit (Function(int, String, String)), che DietView cabla a provider.updateDietMeal (Pezzo 7). Ma onEdit non viene mai chiamato dentro MealCard: nel build ci sono solo onNote (136), onSwap (388), onEat (394). → La funzione "modifica piatto" non ha alcun trigger UI: è codice morto cablato ma irraggiungibile.
Nota: questo corregge DV3 — il cliente in realtà non può modificare i piatti (il flusso non parte). O si rimuove onEdit, o si aggiunge il gesto mancante (es. long-press sul nome).

🟡 DS1 — MEDIO · design system (radice di incoerenze) · design_system.dart:184
PillButton fa onTap: isLoading ? null : onPressed: con onPressed == null il tap è disabilitato ma il colore resta invariato. Semantics(enabled: onPressed != null) è corretto (accessibilità ok), ma visivamente non si vede che è disattivato. È la radice dei finding ricorrenti "bottone colorato ma inerte" (P2, DV3-nota, SS2, MM3): ogni chiamante deve ricordarsi di passare colori muted a mano, e molti non lo fanno.
Raccomandazione: far grigiare PillButton automaticamente quando onPressed == null && !isLoading (un fix centrale che chiude molti finding a valle).

⚪ MR1 — INFO · meal_reminder_dialog.dart:72-81
_loadSettings fa int.parse sull'orario salvato senza try/catch: se la stringa fosse corrotta → eccezione non gestita → spinner infinito nel dialog. Bassa probabilità (dato scritto dallo stesso dialog in HH:mm).

Copertura OK: MealCard display solido (swap/eat/note cablati, scaling porzioni, modalità relax, icone disponibilità); MealReminderDialog switch/time-picker/salva tutti con effetto + feedback + richiesta permessi; PillButton accessibile. Widget "puri" (state_views, password_checklist, skeleton_loaders, badge overlay/sheet, diet_logo) sono display-only, basso rischio.

📋 AUDIT — Pezzo 10a: Services core (FirestoreService, XpService)
🔴 BS1/XP1 — CRITICO · SECURITY (economia XP falsificabile) · xp_service.dart:148-152, 182-184
Confermato dal codice. L'intera economia XP è client-autoritativa:

addXp calcola _totalXp += amount e scrive direttamente xp_total su users/{uid} (riga 148). Nessun coinvolgimento server nel guadagnare XP.
spendXp scrive direttamente xp_total (riga 182).
Le Firestore rules permettono all'owner di scrivere xp_total/xp_today/unlocked_badges (whitelist, firestore.rules:47).
Anche xp_history è scritto dal client (arrayUnion, riga 161) → anche un ricalcolo server dallo storico sarebbe forgiabile.
Exploit: un utente scrive xp_total: 999999 (via SDK Firestore, permesso dalle rules) → il gate client del riscatto passa → POST /rewards/claim/{id}. Se il server valida contro xp_total (client-scritto), ottiene premi reali gratis. Non esiste alcuna fonte XP autorevole lato server nel client.
Raccomandazione (server + rules):

Assegnare/decrementare XP solo lato server (Admin SDK) su eventi verificati;
Rimuovere xp_total/xp_today/unlocked_badges dalla whitelist owner nelle rules;
Il claim premi deve validare contro il saldo server-side, mai contro il campo client.
→ Priorità #1 dell'audit backend.
🔵 FS1 — BASSO · STATE · firestore_service.dart:220-226
getDietHistory su item con decifratura fallita restituisce {'id':.., 'error':'decryption_failed'}. HistoryScreen però lo renderizza come card normale (data → "adesso", titolo "Dieta del …") e il Ripristina su di esso passerebbe garbage a DietPlan.fromJson → rottura. Item d'errore non filtrato/segnalato in UI.

🔵 FS2 — BASSO · silent failure · firestore_service.dart:74-76
saveCurrentDiet ingoia gli errori (solo debugPrint) → salvataggio cloud fallito invisibile (coerente con D2, Pezzo 4).

Copertura OK (FirestoreService): ✅ tutte le scritture dieta cifrate (plan/subs/swaps/weeks), path owner-scoped conformi alle rules, cancellazione fossili legacy, decrypt con try/catch per-item, config in chiaro giustificata (non-PII).

📋 AUDIT — Pezzo 10b: Services gamification/dati (Tracking, Challenge, Badge, Health, Storage)
🔑 Sintesi sistemica: la gamification è disallineata dalle Firestore rules
Confronto codice ↔ firestore.rules (whitelist owner-update riga 47 + catch-all riga 227). Emergono due facce dello stesso problema:

Dato scritto dal client	Rule	Effetto
xp_total, xp_today, unlocked_badges	✅ in whitelist	Persiste MA client-forgiabile → exploit (XP1)
users/{uid}/challenges/{date}	❌ nessuna rule → deny	Scrittura negata → non persiste
badge_counters.*	❌ non in whitelist → deny	Negato → contatori non persistono
streak_last_login, streak_count	❌ non in whitelist → deny	Negato → streak login non persiste
I campi che persistono sono falsificabili; quelli che non persistono rompono la feature. Tutte le scritture negate sono ingoiate (catch + debugPrint), quindi invisibili.

Findings
🔴 SV1 — ALTO · SECURITY (XP farmabile) + BROKEN_FLOW · challenge_service.dart:190,278 ↔ firestore.rules:227
La subcollection challenges non ha regole → cade nel catch-all deny. ChallengeService cattura l'errore e rigenera le sfide localmente (deterministiche per giorno). Conseguenze:

Completamento sfide non persiste → a ogni cold-start le stesse 3 sfide tornano "da fare";
XP farmabile: completa sfida → addXp persiste (xp_total è whitelisted) → riavvia app → sfida di nuovo incompleta → ricompleta → altri XP. Compone con XP1 (Pezzo 10a).
Raccomandazione: o assegnare gli XP sfida server-side, o (minimo) aggiungere una rule per challenges e rendere idempotente il completamento — ma la vera fix resta l'assegnazione XP server-side.
🟡 SV2 — MEDIO · BROKEN_FLOW (gamification rotta) · badge_service.dart:132,151,266
badge_counters.*, streak_last_login, streak_count non sono nella whitelist owner → le update vengono negate (silenziosamente). Effetti:

Badge progressivi (contatori: pesate, giorni completi, viste statistiche, dispensa, condivisioni) → i contatori non persistono tra sessioni → i badge ad alta soglia sono di fatto irraggiungibili (servirebbe raggiungere la soglia in un'unica sessione);
Streak di login → streak_count non salvato → resetta sempre.
(unlocked_badges invece è whitelisted, quindi i badge già sbloccati restano.)
Raccomandazione: aggiungere badge_counters, streak_last_login, streak_count alla whitelist (o gestirli server-side per coerenza con la fix XP).
🔵 SV3 — BASSO · ORPHAN (badge irraggiungibili) · badge_service.dart:302,345,377
Tre trigger sono commentati e marcati [DEAD]: checkWeeklyChallenge, onMealSwapped, checkPerfectWeek. I badge weekly_challenge, swap_master, perfect_week esistono nel registry ma non possono essere sbloccati (nessun caller). Codice morto documentato.

🔵 SV4 — BASSO (auto-documentato) · storage_service.dart:107-109
meal_alarms è su SharedPreferences in chiaro (leggibile su device rooted), mentre il resto dei dati comportamentali è su FlutterSecureStorage. Il TODO nel codice lo riconosce già.

Copertura (verificato OK)
✅ TrackingService: weight/stats/goals/notes su subcollection con rule isOwner → conformi; CRUD pulito.
✅ StorageService: dieta/dispensa/swap/allarmi su FlutterSecureStorage (AES-256 + Keystore/Keychain); clearAll (logout) svuota prefs e secure storage.
✅ HealthService: sola lettura, permission-gated, null-graceful su piattaforme non supportate; nessuna scrittura.
⚠️ PII in chiaro (coerente con CH5): weight_history, meal_notes, daily_stats non cifrati su Firestore — protetti da rules + at-rest.

═══════════════════════════════════════════════════════════════════════════════
# PARTE 2 — AUDIT SERVER (server/app/routers/)
═══════════════════════════════════════════════════════════════════════════════

Metodo: endpoint per endpoint. Per ognuno — auth dependency appropriata? autorizzazione/ownership oltre l'auth? validazione input (Pydantic/path/query)? rate limit? injection? info leak (sanitize_error_message)? integrità logica di business? reachability.
Nota chiave: il server usa l'Admin SDK → BYPASSA le Firestore rules. È lui il vero punto di enforcement. Deps: verify_token (autenticato), verify_admin, verify_professional, get_current_uid.

───────────────────────────────────────────────────────────────────────────────
## SRV-1 — rewards.py — Shop Premi
Endpoint: admin CRUD catalogo (GET/POST/PUT/DELETE /admin/rewards/catalog), admin claims (GET /admin/rewards/claims, POST .../{uid}/{claim}/fulfill), client (GET /rewards/catalog, POST /rewards/claim/{id}, GET /rewards/my-claims).

🔴 SRV-RW1 — CRITICO · SECURITY (economia premi falsificabile) · rewards.py:343,361
claim_reward legge il saldo da user_data.get('xp_total') (pre-check 343, e DENTRO la transazione 361). Ma xp_total è scritto dal client (firestore.rules:47 lo whitelista; XpService lo aggiorna client-side). La transazione garantisce l'atomicità (no doppia spesa in race) MA NON l'autenticità del saldo: un utente che scrive xp_total:999999 sul proprio doc (permesso dalle rules) supera il check e ottiene un claim 'pending' → l'admin poi lo evade (POST .../fulfill) → premio reale consegnato.
→ Conferma END-TO-END di XP1/BS1. rewards.py è corretto in sé; il difetto è che la fonte di verità XP è client-controllata.
Raccomandazione: (1) assegnare/spendere XP SOLO server-side su eventi verificati; (2) RIMUOVERE xp_total/xp_today/unlocked_badges dalla whitelist owner in firestore.rules. Senza (2), nessun controllo su claim è affidabile.

Copertura OK:
✅ Admin CRUD tutto dietro verify_admin; client dietro verify_token/get_current_uid.
✅ Validazione input forte: CreateRewardRequest/UpdateRewardRequest con Field range; AnyHttpUrl su image_url/redirect_url (blocca schemi non http/https → mitiga XSS/SSRF stored).
✅ Transazione atomica su claim (xp + stock + record), ri-verifica is_active/stock/xp dentro la txn; fulfill idempotente in transazione (409 se non 'pending').
✅ Rate limit su tutti; sanitize_error_message + detail generici (no leak); catalogo pubblico rimuove created_by; soft-delete preserva lo storico.
✅ new_xp_total ritornato è il valore reale post-txn (il client lo ignora → RW1 client, Pezzo 8a).

───────────────────────────────────────────────────────────────────────────────
## SRV-2 — users.py — Gestione utenti (admin/professional)
Endpoint: POST /admin/create-user, PUT /admin/update-user/{uid}, POST /admin/assign-user, POST /admin/unassign-user, DELETE /admin/delete-user/{uid}, DELETE /admin/delete-diet/{id} (+ altri).

⚪ SRV-U1 — INFO (positivo, chiude F1 lato server) · users.py:121-127,46-52
La create-user lato server NON produce il bug F1: se il creatore non è admin il ruolo è forzato a 'user' (121-122), e CreateUserRequest.validate_role ammette ['user','independent','nutritionist','personal_trainer','coach','admin'] — NON 'client'. Il server scrive sempre ruoli validi per le rules. → F1 è puramente client-side (self-signup che scrive 'client' diretto su Firestore).

🔵 SRV-U2 — BASSO · SECURITY (validazione assegnazione) · users.py:266-285
assign-user (admin-only) non verifica che body.nutritionist_id sia effettivamente un professionista (controlla solo esistenza doc + max_clients). Admin è fidato → rischio basso, ma un typo assegnerebbe clienti a un UID non-nutrizionista.

Copertura OK:
✅ create/update/assign/unassign-user dietro verify_admin; delete-user dietro verify_professional CON controllo ownership per i nutrizionisti (parent_id/created_by == requester) e 403 costante anti-enumerazione UID (users.py:338-345).
✅ Cambio ruolo/limite loggati in access_logs; delete-user cascade completa (diet_history + subcollections + auth user) — GDPR.
✅ email_verified=False + requires_password_change/requires_email_verification alla creazione (flussi già auditati lato client).
✅ Validazione Pydantic su tutti i body; sanitize_error_message ovunque.

───────────────────────────────────────────────────────────────────────────────
## SRV-3 — shopping_share.py — Lista condivisa
Endpoint: POST /shopping-list/share (crea snapshot), GET /shopping-list/share/{id} (pubblico).

🔵 SRV-SH1 — BASSO/MEDIO · SECURITY (write non autenticato) · shopping_share.py:35-37
POST /shopping-list/share NON ha dependency di auth (create_share(request, req) — nessun verify_token). Chiunque, anche non autenticato, può creare snapshot su Firestore (shared_lists) e ottenere un URL kybo.it/list?id=... Mitigazioni presenti: rate limit 10/ora/IP, items cap 200 + 200 char, title cap 100, ID random (secrets.token_urlsafe). Rischio: abuso come storage di testo effimero e — più rilevante — far ospitare a kybo.it/list contenuti arbitrari di un attaccante (vettore reputazione/phishing, capato).
Raccomandazione: aggiungere Depends(verify_token) al POST (solo utenti loggati creano share); la GET resta pubblica by-design.

Copertura OK:
✅ GET pubblica by-design ma difesa: regex SHARE_ID_RE su share_id (404 se non matcha), check TTL 7gg (410 se scaduto), ritorna solo items/title.
✅ Input sanitizzato/capato; ID ad alta entropia; append &dev=1 per ENV != PROD.

───────────────────────────────────────────────────────────────────────────────
## SRV-4 — chat.py — Upload allegati (✅ esemplare)
Endpoint: POST /chat/upload-attachment (verify_token).
Nessun finding. Difese esemplari:
✅ verify_token (any authenticated — corretto per canale bidirezionale client↔professionista).
✅ Allowlist Content-Type + allowlist estensione + MAX_FILE_SIZE + validate_file_content (MAGIC BYTES) → difende dallo spoofing del Content-Type client-controllato.
✅ Signed URL ridotto a 1 ORA (era 7 giorni) — un URL rubato scade presto. sanitize_error_message.
⚪ Nota (INFO): i file vanno in chat_uploads/{uuid} (path flat, non scoped per-chat); l'access control reale è il signed URL 1h + il fatto che l'URL è nel doc messaggio (participant-scoped). Un admin che elenca il bucket vede tutti gli allegati. Accettabile.

───────────────────────────────────────────────────────────────────────────────
## SRV-5 — matchmaking.py — Matchmaking (✅ eccellente)
Endpoint: POST /requests, GET /board, POST /requests/{id}/offers, GET /my-requests, POST /requests/{id}/accept, DELETE /requests/{id}, DELETE /requests/{id}/offers/mine.
Nessun finding di sicurezza. Router già passato per una security pass (vedi commenti [FIX H/M/L]):
✅ create_request: solo ruoli client/independent/user (403 altrimenti), dedup richiesta aperta, coach_type validato.
✅ board (verify_professional): filtra per ruolo, RIMUOVE user_id (anti-enumerazione UID client).
✅ make_offer (verify_professional): admin escluso, role deve combaciare con coach_type, dedup offerta per uid in transazione.
✅ accept_offer (verify_token): ownership richiesta, VERIFICA che il professionista esista e abbia il ruolo giusto prima di assegnarlo (FIX H-1), transazione atomica (assegna coach + chiudi richiesta + rifiuta altre offerte) con re-check race.
✅ cancel/withdraw: ownership + status check + transazioni.
⚪ Nota (INFO, coerente con MM4 client): goal/notes (possibili dati sanitari) in chiaro, visibili ai professionisti via board — opt-in dell'utente.

───────────────────────────────────────────────────────────────────────────────
## SRV-6 — diet.py + diet_save_service.py — Pipeline AI/OCR + PDF
Endpoint: POST /upload-diet (self), GET /diet/job/{id}, POST /upload-diet/{uid} (professional), POST /scan-receipt, GET /export-diet-pdf, POST /import-diet.

🟡 SRV-DIET1 — MEDIO · BROKEN_FLOW + SECURITY (formato dieta incoerente server↔client) · diet.py:443 + diet_save_service.py:21
Due formati CONFLITTUALI per users/{uid}/diets/current:
- SERVER (upload-diet / worker RQ → save_diet_to_firestore) scrive `plan`/`substitutions`/`config` in **CHIARO**, senza flag `encrypted`, con `.set()` (overwrite).
- CLIENT (FirestoreService.saveCurrentDiet) scrive `plan_encrypted` + `encrypted:true` e **CANCELLA** `plan` (`.set(merge:true)`).
Conseguenze:
  (a) **export-diet-pdf ROTTO**: legge `diet_data.get('plan', {})` (443), che è **assente** dopo qualsiasi salvataggio client (swap giorno, modifica pasto, sync). Genera un PDF **vuoto** ("Nessun piano alimentare disponibile") in silenzio. Funziona solo subito dopo un upload server, prima che il client tocchi la dieta.
  (b) **Diete caricate dal nutrizionista salvate in CHIARO** su Firestore (il path server non cifra) → l'offuscamento client è bypassato sul path più comune (upload professionista). Contraddice l'affermazione "crittografia" (lega a ST2). L'`.set()` server sovrascrive anche i campi `_encrypted` → ping-pong di formato tra upload server e re-save client.
Raccomandazione: unificare il formato (o il server cifra come il client, o l'export decifra `plan_encrypted` server-side derivando la chiave dall'uid). Decidere UNA sorgente di verità per il formato di `diets/current`.

⚪ SRV-DIET2 — INFO · import-diet · diet.py:521-567
`import-diet` scrive `plan` in chiaro (557) come il path server (stessa incoerenza). Inoltre **nessun caller client** è stato visto nell'audit UI → possibile endpoint orphan/futuro (DA VERIFICARE se una schermata lo invoca).

Copertura OK (ottima):
✅ Auth + role: upload-diet self (verify_token, solo independent/admin/nutritionist), upload-diet/{uid} (verify_professional + **ownership**: parent_id/created_by/nutritionist_id == requester), scan/export/import (get_current_uid).
✅ File: estensione + size (max_file_size_mb) + **validate_file_content (magic bytes)** su PDF e immagini; allowed_foods capato 5000; import capato 5MB + estensioni allowlist.
✅ get_diet_job: owner check (owner_uid == requester o admin/nutritionist) anti-enumerazione + strip owner_uid dalla response.
✅ Concorrenza: heavy_tasks_semaphore sui task pesanti; path RQ asincrono con owner_uid nel meta; fallback sincrono.
✅ Injection: nessun eval/exec/SQL; Gemini/Tesseract via services; output coerciato nello schema DietResponse; fpdf rende solo testo; import CSV sanitizza campi (strip control-char + length caps → anti stored-XSS).
✅ sanitize_error_message + detail generici ovunque.
⚪ Nota: `custom_parser_prompt` (impostato dal nutrizionista) è iniettato nel prompt Gemini → possibile prompt-injection ma limitata ai propri clienti e coerciata nello schema. Basso.

───────────────────────────────────────────────────────────────────────────────
## SRV-7 — gdpr.py — Privacy/consenso/export/retention (✅ ottimo)
Endpoint: POST/GET /gdpr/consent, GET /gdpr/export, GET /gdpr/export/{uid} (professional), GET /gdpr/admin/dashboard, GET/POST /gdpr/admin/retention-config, POST /gdpr/admin/purge-inactive.

🟡 SRV-GDPR1 — MEDIO · BROKEN_FLOW (erasure non self-service) · gdpr.py ↔ users.py:321-326
Esiste l'export self-service (/gdpr/export) ma NON un endpoint di **cancellazione account self-service**: delete-user è verify_professional (admin/nutritionist), purge è verify_admin. Un utente 'user'/'independent' NON può cancellarsi da solo (verify_professional lo rifiuta con 403). Combinato con ST1 (nessuna UI client per export/delete), il diritto all'oblio (Art. 17) richiede l'intervento di admin/professionista. Ammissibile via richiesta, ma non self-service.
Raccomandazione: valutare un endpoint /gdpr/delete-me (verify_token, cancella il proprio account) + UI in Settings.

⚪ SRV-GDPR2 — INFO · gdpr.py:36-74
Il docstring di record_consent dichiara "tracciata con IP per compliance" e il modello ConsentResponse ha `ip_address`, ma il consent_record NON cattura l'IP (request.client.host / X-Forwarded-For). Claim di compliance non implementato.

Copertura OK (esemplare):
✅ /export self (verify_token, propri dati) + /export/{uid} (professional con **ownership** parent_id==requester + audit access_logs).
✅ _collect_export_data rimuove campi interni (requires_password_change, created_by), CAP su didiete/history/logs (anti multi-MB/DoS/leak nei log).
✅ retention-config validata (6–120 mesi), purge admin-only rate-limited 5/ora con **dry_run=True di default** e audit log completo.
✅ Nota positiva: gli endpoint GDPR self-service esistono lato server → basta la UI client (chiude metà di ST1).

───────────────────────────────────────────────────────────────────────────────
## SRV-8 — suggestions.py — Suggerimenti pasti AI (Gemini)
Endpoint: GET /meal-suggestions (verify_token + get_current_uid).

🔵 SRV-SUG1 — BASSO · SECURITY (info leak) · suggestions.py:151-152
A differenza del resto del server, l'error handler ritorna `str(e)[:200]` al client: `f"Errore nella generazione dei suggerimenti: {error_detail}"`. Espone l'eccezione grezza (errori Gemini/interni) invece di un messaggio generico.
Raccomandazione: usare sanitize_error_message + detail generico come negli altri router.

🔵 SRV-SUG2 — BASSO · SECURITY (prompt injection self-scoped) · suggestions.py:258
Il query param `meal_type` è interpolato grezzo nel prompt Gemini (`f"...pasto: {meal_type}."`). Un utente può iniettare istruzioni ("ignora le regole..."). Impatto limitato: colpisce solo i PROPRI suggerimenti e l'output è coerciato nello schema SuggestedDish (JSON). Basso, ma è input non validato in un prompt LLM.

⚪ Cross-ref SRV-DIET1 · suggestions.py:184
`_load_user_context` legge `diet_data.get("plan", {})` in CHIARO → per le diete cifrate dal client (plan cancellato) il contesto è vuoto → i suggerimenti perdono la personalizzazione sulla dieta (fallback generico). Stessa causa di SRV-DIET1: più feature server leggono il `plan` che il client cancella.

Copertura OK:
✅ verify_token + validazione query (count 1–12, pantry cap 100); cache L1 RAM + L1.5 Redis con chiave MD5 (usedforsecurity=False documentato); metriche instrumentate; rate limit 60/min; output JSON strutturato via response_mime_type.

───────────────────────────────────────────────────────────────────────────────
## SRV-9 — twofa.py — Two-Factor Auth (✅ router pulito)
Endpoint: POST /admin/2fa/setup|verify|validate|disable|backup-codes/regenerate, GET /admin/2fa/status.

⚪ SRV-2FA1 — INFO/DA VERIFICARE · dipende da TOTPService
Il router è corretto: setup/verify/disable/regenerate dietro verify_professional, validate/status dietro verify_token; disable e regenerate RICHIEDONO un codice 2FA valido; setup non salva il secret finché non c'è verify; rate limit adeguati (validate 30/min → brute-force TOTP a 6 cifre non praticabile su finestra 30s). La sicurezza REALE (secret cifrato a riposo? backup codes hashati? confronto constant-time? protezione replay/finestra TOTP?) è in services/totp_service.py → DA VERIFICARE lì.

Copertura OK: scoping auth corretto, sanitize_error_message, verifica codice richiesta per operazioni sensibili, gestione "già abilitato".

───────────────────────────────────────────────────────────────────────────────
## SRV-10 — admin.py — Sync/config/manutenzione/gateway PII (✅ ben protetto)
Endpoint: POST /admin/sync-users, /admin/upload-parser/{uid}, /admin/log-access, GET /admin/user-history/{uid}, /admin/users-secure, /admin/user-details-secure/{uid}, GET/POST /admin/config/maintenance, /admin/schedule-maintenance, /admin/cancel-maintenance, GET/POST /admin/config/app.

🔵 SRV-ADM1 — BASSO · STATE (audit log best-effort) · admin.py:308-310
get_user_details_secure scrive l'audit log PII con asyncio.create_task(run_in_threadpool(_log_access_bg, ...)) fire-and-forget: sotto carico/errore il log di accesso ai dati (READ_USER_PROFILE) potrebbe non essere scritto. Per integrità forense l'audit di accesso PII dovrebbe essere garantito (await o coda affidabile).

Copertura OK:
✅ Tutti gli endpoint dietro verify_admin o verify_professional; endpoint professional applicano OWNERSHIP (parent_id/created_by/nutritionist_id/pt_id == requester) prima di restituire dati utente (user-history, users-secure via Or filter, user-details-secure).
✅ Accessi PII loggati in access_logs (user-history, user-details, log-access); maintenance/app-config solo admin, merge writes.
✅ upload-parser: cap 50KB + strip control-char + parser_history troncato; sync-users con batch a chunk (MAX_BATCH_SIZE 500) e claims parallelizzati.
✅ sanitize_error_message; nessuna injection.

───────────────────────────────────────────────────────────────────────────────
## STATO AUDIT SERVER — coperti 10/18 router
Fatti: rewards, users, shopping_share, chat, matchmaking, diet(+diet_save_service), gdpr, suggestions, twofa, admin.
Restano: analytics.py, communication.py, reports.py, newsletter.py, diet_templates.py, workouts.py, profile.py (endpoint /profile — upload-photo + i miei complete-password-change/complete-email-verification), users.py:delete-diet.
Infra da verificare: main.py (middleware ContentSizeLimit, CORS, /system/status, /metrics), core/dependencies.py (validate_file_content magic bytes, semaphore, rate limiter key), core/config.py, services/totp_service.py (SRV-2FA1), services/gdpr_retention_service.py.

## TOP FINDING SERVER (finora)
1. 🔴 SRV-RW1 — reward claim si fida di xp_total client-writable → conferma end-to-end di XP1 (premi reali gratis). Fix: XP server-side + rimuovere xp_total dalla whitelist rules.
2. 🟡 SRV-DIET1 — formato dieta incoerente server(chiaro)↔client(cifrato): export-PDF esce VUOTO dopo il primo save client; diete del nutrizionista salvate in CHIARO; suggestions perdono personalizzazione.
3. 🟡 SRV-GDPR1 — nessuna cancellazione account self-service (solo admin/professional) — lega a ST1 client.
4. 🔵 SRV-SH1 (share POST senza auth), SRV-SUG1 (leak str(e)), SRV-SUG2 (prompt-injection self), SRV-ADM1 (audit PII fire-and-forget).
Nota trasversale: la maggior parte dei router è **ben ingegnerizzata** (transazioni atomiche, ownership check, anti-enumerazione, validazione Pydantic, magic-bytes, rate limit, sanitize_error_message). Il problema strutturale è l'**economia XP client-autoritativa** (SRV-RW1/XP1) e l'**incoerenza di formato dieta** (SRV-DIET1).

───────────────────────────────────────────────────────────────────────────────
## SRV-11 — analytics.py — Metriche pannello (✅ ben protetto, PII masking)
Endpoint: GET /admin/analytics/overview, /diet-trend, /nutritionist-activity, /inactive-users, /meal-completion/{uid}.

⚪ SRV-AN1 — INFO · analytics.py:410-420 · cross-ref SRV-DIET1
meal-completion legge `plan` in CHIARO (planned_meals_per_day) → skew per diete cifrate dal client; inoltre interroga la subcollection `meal_tracking` che il client NON scrive (scrive daily_stats) → possibile collection mismatch → total_meals_logged ~0. DA VERIFICARE.

⚪ SRV-AN2 — INFO · analytics.py:263-264
inactive-users MASCHERA la PII dei clienti per l'admin (_mask_email/_mask_name), ma nutritionist-activity ritorna email/nome dei nutrizionisti in CHIARO all'admin. Incoerenza di masking, probabilmente intenzionale (staff vs client PII).

Copertura OK: tutti verify_professional con ownership filter (Or su parent_id/nutritionist_id/pt_id/created_by), CAP su ogni query (_MAX_*), masking PII client per admin, validazione query (period regex, days/months range).

───────────────────────────────────────────────────────────────────────────────
## SRV-12 — workouts.py — Schede allenamento (✅ eccellente + precedente XP server-side)
Endpoint: GET/POST/PUT/DELETE /workouts/plans(+/{id}), POST assign|clone-and-assign, GET /workouts/my-plan|history, POST /workouts/complete-day|feedback.

⚪ SRV-WO1 — INFO (RINFORZA SRV-RW1) · workouts.py:589-608
complete-day assegna XP **SERVER-SIDE** correttamente: `firestore.Increment(_WORKOUT_XP)` dentro una TRANSAZIONE, idempotente per giorno (completion_ref = data), con record xp_history. → **Prova che l'XP server-side è già implementato e fattibile.** MA il client può comunque **sovrascrivere** `xp_total` (rules whitelist), quindi anche questo XP corretto è vanificato: l'economia è forte quanto lo scrittore più debole (il client). Rinforza la fix SRV-RW1 (vietare la scrittura client di xp_total).

⚪ SRV-WO2 — INFO · reachability
La feature workout è DISABILITATA nel client ([DISABLED workout feature] in home_screen). Questi endpoint non hanno caller client attualmente (dormienti ma ben costruiti per la riattivazione).

Copertura OK: verify_professional + ownership (created_by/target parent_id/pt_id); transazioni atomiche su assign/complete-day (anti doppio-credito XP + anti-race riassegnazione); soft-delete; rate limit stretti (complete-day 5/day); validazione Pydantic (Exercise/WorkoutDay range).

───────────────────────────────────────────────────────────────────────────────
## SRV-13 — communication.py — Broadcast + note interne (✅ eccellente)
Endpoint: GET/POST /admin/communication/email-alert-config, POST /broadcast, GET/POST/PUT/DELETE /notes/{client_uid}(+/{note_id}).
Nessun finding. Ownership rigoroso:
✅ broadcast: nutritionist→propri clienti, admin→propri nutrizionisti (admin non messaggia mai i clienti — privacy); message cap 5000; batch a chunk; audit log.
✅ internal_notes: ownership su client_uid (parent_id/created_by/nutritionist_id/pt_id) SU OGNI operazione + author check (solo autore o admin modifica/cancella); ex-nutrizionista bloccato su clienti riassegnati (documentato [SECURITY]); content cap 10000.
✅ email-alert-config: propria config, threshold clamp 1–30.

───────────────────────────────────────────────────────────────────────────────
## SRV-14 — reports.py — Report mensili nutrizionisti (✅ pulito)
Endpoint: GET /admin/reports/monthly|list|{id}, POST /generate, DELETE /{id} (admin).
Nessun finding: verify_professional con permission check (admin o requester==nutritionist_id); get_report_by_id estrae nutritionist_id dall'ID e verifica ownership; validazione anno (2020–now) e mese (1–12); delete solo admin; sanitize_error_message.

───────────────────────────────────────────────────────────────────────────────
## SRV-15 — diet_templates.py — Template dieta riutilizzabili (✅ pulito)
Endpoint: GET/POST /diet-templates, DELETE /{id}, POST /{id}/clone-and-assign/{uid}.
Nessun finding di sicurezza: verify_professional + ownership (created_by/target); PDF magic-bytes + name/size cap; listing rimuove parsed_data (bandwidth).
⚪ Cross-ref SRV-DIET1: clone-and-assign usa save_diet_to_firestore → scrive `plan` in CHIARO (stessa incoerenza formato; le diete da template nascono non cifrate).

───────────────────────────────────────────────────────────────────────────────
## SRV-16 — newsletter.py — Newsletter + Contact form (pubblici by-design)
Endpoint: POST /newsletter/subscribe|unsubscribe, POST /contact/submit.

🔵 SRV-NL1 — BASSO · SECURITY (write pubblico) · newsletter.py:32,57,85
Tutti e tre gli endpoint sono **senza auth** (landing page): scrivono su Firestore (newsletter_subscribers, contact_requests). Mitigazioni: EmailStr validata, rate limit (10/h subscribe, 5/h contact), name cap 100 / message cap 2000, dedup subscribe. Rischio: spam-fill delle collection (come SRV-SH1) + **niente double opt-in** sulla newsletter (si può iscrivere l'email altrui). Standard per form pubblici, accettabile con i rate limit.

───────────────────────────────────────────────────────────────────────────────
## SRV-17 — users.py (coda) — delete-diet, session/revoke (✅ pulito)
✅ delete-diet (verify_professional): ownership per nutrizionista (uploadedBy==requester o parent_id del client); audit log; 200 "Already deleted" se assente (no leak).
✅ session/revoke/{uid} (verify_admin): revoca refresh token (force logout); il JWT corrente resta valido max 1h (documentato).

───────────────────────────────────────────────────────────────────────────────
## SRV-18 — profile.py — Foto profilo + finalizzazione flussi (✅ pulito)
Endpoint: POST /profile/upload-photo, DELETE /profile/photo, POST /profile/complete-password-change, POST /profile/complete-email-verification.
✅ upload-photo: verify_token + allowlist type/estensione + MAX_FILE_SIZE + validate_file_content (magic bytes) + signed URL 7gg. complete-email-verification verifica email_verified via Admin SDK (non falsificabile). Tutti operano sul proprio uid (verify_token/requester['uid']). sanitize_error_message.

═══════════════════════════════════════════════════════════════════════════════
## INFRA — main.py + config.py + dependencies.py
═══════════════════════════════════════════════════════════════════════════════

⚪ SRV-MAIN1 — INFO (commento stale) · main.py:334
Il commento in `/system/status` dice "L'endpoint è pubblico (no auth)" ma l'endpoint È protetto (`Depends(verify_admin)` a riga 306). Commento fuorviante; il codice è corretto.

Copertura OK (infra esemplare):
✅ ContentSizeLimitMiddleware: rifiuta i body oversize via Content-Length PRIMA del buffering → anti memory/disk DoS.
✅ CORS: `allow_origins=settings.ALLOWED_ORIGINS` **per-ambiente** (PROD = solo domini prod, NESSUN wildcard) + allow_credentials, metodi/headers ristretti. (config.py:36 conferma no `*`.)
✅ /metrics, /metrics/api, /system/status, /health/detailed → tutti **verify_admin** (i metrics grezzi elencano endpoint/latenze/error-rate: ricognizione — protetti). /health e /ping pubblici e leggeri.
✅ /system/status: messaggi generici (no str(e), no versioni precise → no fingerprinting); subprocess `tesseract --version` con args FISSI, no shell=True, timeout 5 → no injection.
✅ Firebase init sanitizza gli errori (strip Bearer/token); Sentry send_default_pii=False; rate-limit handler globale.

═══════════════════════════════════════════════════════════════════════════════
## CONCLUSIONE AUDIT SERVER — 18/18 router + infra coperti
═══════════════════════════════════════════════════════════════════════════════

**Giudizio generale: il backend è di ALTA qualità.** Pattern ricorrenti positivi su quasi tutti i router:
transazioni atomiche (claim/assign/complete), ownership check + anti-enumerazione UID, validazione Pydantic con range, magic-bytes su ogni upload, rate limit ovunque, `sanitize_error_message` + detail generici, audit log su accessi PII/azioni sensibili, soft-delete per preservare lo storico, CAP sulle query Firestore (anti-DoS/costi), CORS per-ambiente, body-size middleware, metrics/status admin-only.

**Finding server per severità:**
- 🔴 **SRV-RW1 (CRITICO)** — reward claim si fida di `xp_total` client-writable → premi reali gratis. È la conferma end-to-end di XP1. NB: `workouts.complete-day` (SRV-WO1) dimostra che il server SA già assegnare XP server-side in transazione — ma è vanificato dal fatto che il client può sovrascrivere `xp_total`. **Fix: (1) XP solo server-side; (2) rimuovere `xp_total`/`xp_today`/`unlocked_badges` dalla whitelist owner in firestore.rules.**
- 🟡 **SRV-DIET1 (MEDIO)** — formato dieta incoerente server(chiaro)↔client(cifrato): export-PDF vuoto dopo il 1° save client; diete del nutrizionista/template salvate IN CHIARO; suggestions/analytics leggono il `plan` cancellato. Tocca diet.py, diet_save_service, suggestions, analytics, diet_templates. **Fix: unificare il formato di `diets/current`.**
- 🟡 **SRV-GDPR1 (MEDIO)** — nessuna cancellazione account self-service (lega a ST1 client).
- 🔵 Bassi: SRV-SH1 (share POST no-auth), SRV-NL1 (form pubblici), SRV-SUG1 (leak str(e)), SRV-SUG2 (prompt-injection self), SRV-ADM1 (audit PII fire-and-forget), SRV-U2 (assign senza check ruolo nutrizionista).
- ⚪ Info/verificare: SRV-2FA1 (totp_service.py da leggere), SRV-AN1/AN2, SRV-WO2 (workout dormiente), SRV-MAIN1 (commento stale).

**Sintesi finale (client + server):** i DUE problemi strutturali sono
1. **Economia XP/premi client-autoritativa** (XP1 + SRV-RW1) — l'unico finding CRITICO end-to-end. Il resto della gamification (SV1/SV2) è rotto in silenzio per disallineamento rules.
2. **Incoerenza di formato dieta** server-chiaro / client-cifrato (SRV-DIET1) — rompe export-PDF e lascia diete PII in chiaro.
Entrambi si risolvono lato **server + Firestore rules**. Tutto il resto è polish (leak `$e`, controller non-disposti, conferme mancanti su azioni distruttive, empty states, flussi GDPR self-service).

═══════════════════════════════════════════════════════════════════════════════
## SERVICES CRITICI — totp_service.py + gdpr_retention_service.py
═══════════════════════════════════════════════════════════════════════════════

### SRV-19 — totp_service.py — 2FA (TOTP RFC 6238)

🟡 SRV-2FA-A — MEDIO · SECURITY (secret 2FA in chiaro) · totp_service.py:220
`two_factor_secret` è salvato in **CHIARO** nel doc `users/{uid}` (riga 220, e regen 342). Un dump/breach Firestore espone TUTTI i secret TOTP → 2FA completamente aggirabile (l'attaccante genera codici validi). Inoltre le Firestore rules permettono la read del doc utente all'owner e all'admin/professionista assegnato → il secret è leggibile oltre al server.
Raccomandazione: cifrare il secret a riposo con una chiave server-side (env/KMS), non co-locata col ciphertext. (Il secret deve restare recuperabile per verificare → serve cifratura reversibile, non hash.)

🔵 SRV-2FA-B — BASSO · SECURITY (no replay protection) · totp_service.py:111-134
`_verify_totp` non traccia il time-step consumato → un codice TOTP valido è **riutilizzabile** entro la finestra ±1 (~90s). Mitigato da rate limit (validate 30/min) e finestra breve. Best practice: memorizzare l'ultimo counter usato e rifiutare i replay.

⚪ SRV-2FA-C — INFO · totp_service.py:157
Backup code = `secrets.token_hex(4)` → 32 bit (8 hex). Adeguati col rate limit, ma sotto lo standard (40–80 bit).

Copertura OK (2FA fatto per lo più bene):
✅ Confronto **constant-time** (`hmac.compare_digest`); backup codes **hashati SHA256** (non in chiaro); consumo backup code **atomico in transazione** (anti-race/replay); secret non salvato finché non verificato; algoritmo RFC 6238 corretto; disable/regenerate cancellano i campi.

### SRV-20 — gdpr_retention_service.py — Retention/purge GDPR

🟡 SRV-RET1 — MEDIO · SECURITY/compliance (erasure INCOMPLETA) · gdpr_retention_service.py:389-420
`purge_user` cancella esplicitamente solo la subcollection **`diets`** (+ diet_history, chats, consent_logs, user doc, auth). Ma Firestore **NON** cancella a cascata le subcollection quando elimini il doc padre → restano **ORFANE con PII**: `weight_history`, `daily_stats`, `goals`, `meal_notes`, `xp_history`, `claimed_rewards`, `internal_notes`, `workout_completions`, `workouts_history`, `challenges`, ecc. Il diritto all'oblio (Art. 17) è quindi **incompleto**: dati sanitari (peso, note pasti, obiettivi) sopravvivono alla "cancellazione" (interrogabili via collection_group).
Nota: `users.py:delete-user` (path admin manuale) fa invece `user_ref.collections()` iterando TUTTE le subcollection → completo. Le due strade di cancellazione sono **incoerenti**.
Raccomandazione: in purge_user usare `user_ref.collections()` come delete-user, invece di elencare solo `diets`.

⚪ SRV-RET2 — INFO · gdpr_retention_service.py:640-641
La dashboard GDPR ritorna le email degli inattivi in CHIARO all'admin (a differenza del masking in analytics/inactive-users, SRV-AN2). Probabilmente voluto (l'admin deve identificare chi purgare), ma incoerente.

Copertura OK: dry_run default True con override LOGGATO; audit log su purge live; `_MAX_SCAN` (50k) con warning; exclude_roles (admin/nutritionist) protetti; cascade su chats+messages.

═══════════════════════════════════════════════════════════════════════════════
## ✅ AUDIT COMPLETO — 18/18 router + infra + 2 service critici
═══════════════════════════════════════════════════════════════════════════════
Aggiornamento finding server: aggiunti 🟡 SRV-2FA-A (secret 2FA in chiaro) e 🟡 SRV-RET1 (purge GDPR incompleta → PII orfana). Portano i MEDI server a: SRV-DIET1, SRV-GDPR1, SRV-2FA-A, SRV-RET1. L'unico CRITICO resta SRV-RW1 (economia XP/premi client-autoritativa).

QUADRO FINALE (client + server + rules + service):
🔴 1 critico — economia XP/premi falsificabile (XP1 + SRV-RW1).
🟡 medi — formato dieta incoerente (SRV-DIET1); GDPR: no self-delete (SRV-GDPR1) + purge incompleta (SRV-RET1); 2FA secret in chiaro (SRV-2FA-A); gamification rotta da rules (SV1/SV2); azioni distruttive senza conferma (HS1); dichiarazione E2E falsa + reset tutorial rotto (ST2/ST3); MealCard.onEdit orfano (MC1); PillButton no auto-grey (DS1); empty dieta fuorviante (DV1); registrazione invito rotta (F1/F2).
🔵 bassi/ricorrenti — leak `$e` in UI, controller dialog non-disposti, share/newsletter POST senza auth, prompt-injection self, audit PII fire-and-forget, TOTP replay, backup code 32-bit.
Il backend e la maggior parte del client sono ben ingegnerizzati; i problemi sono concentrati su (1) economia XP client-autoritativa e (2) coerenza/completezza del data-layer (formato dieta, erasure GDPR, secret 2FA).


