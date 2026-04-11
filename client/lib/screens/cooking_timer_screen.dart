// Timer cottura integrato: preset rapidi (1/2/5/10/15 min), input custom,
// start/pause/reset, vibrazione e notifica sonora alla fine.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/badge_service.dart';
import '../services/challenge_service.dart';
import '../widgets/design_system.dart';

class CookingTimerScreen extends StatefulWidget {
  const CookingTimerScreen({super.key});

  @override
  State<CookingTimerScreen> createState() => _CookingTimerScreenState();
}

class _CookingTimerScreenState extends State<CookingTimerScreen>
    with TickerProviderStateMixin {
  // --- State ---
  int _totalSeconds = 0;
  int _remainingSeconds = 0;
  bool _running = false;
  bool _finished = false;
  Timer? _timer;
  late AnimationController _pulseController;

  static const _presets = [
    (label: '1 min', seconds: 60),
    (label: '2 min', seconds: 120),
    (label: '5 min', seconds: 300),
    (label: '10 min', seconds: 600),
    (label: '15 min', seconds: 900),
    (label: '30 min', seconds: 1800),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // --- Helpers ---
  String get _displayTime {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progress =>
      _totalSeconds == 0 ? 0 : (_totalSeconds - _remainingSeconds) / _totalSeconds;

  void _setPreset(int seconds) {
    _timer?.cancel();
    setState(() {
      _totalSeconds = seconds;
      _remainingSeconds = seconds;
      _running = false;
      _finished = false;
    });
  }

  void _startPause() {
    if (_totalSeconds == 0) return;
    if (_finished) {
      _reset();
      return;
    }
    setState(() => _running = !_running);
    if (_running) {
      // Badge e sfida trigger
      context.read<BadgeService>().onCookingTimerUsed();
      context.read<ChallengeService>().checkAutoComplete('use_timer');
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_remainingSeconds <= 0) {
          _timer?.cancel();
          setState(() {
            _running = false;
            _finished = true;
          });
          _onFinished();
          return;
        }
        setState(() => _remainingSeconds--);
      });
    } else {
      _timer?.cancel();
    }
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = _totalSeconds;
      _running = false;
      _finished = false;
    });
  }

  void _onFinished() {
    HapticFeedback.vibrate();
    // Vibrazione ripetuta (3 impulsi)
    Future.delayed(const Duration(milliseconds: 300), HapticFeedback.vibrate);
    Future.delayed(const Duration(milliseconds: 600), HapticFeedback.vibrate);
    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: KyboColors.surface(context),
          shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⏰', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              Text(
                'Tempo scaduto!',
                style: TextStyle(
                  color: KyboColors.textPrimary(context),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Il tuo piatto è pronto.',
                style: TextStyle(
                  color: KyboColors.textSecondary(context),
                  fontSize: 15,
                ),
              ),
            ],
          ),
          actions: [
            PillButton(
              label: 'OK',
              onPressed: () => Navigator.pop(ctx),
              backgroundColor: KyboColors.primary,
              textColor: Colors.white,
              height: 44,
            ),
          ],
        ),
      );
    }
  }

  void _showCustomDialog() {
    final mCtrl = TextEditingController();
    final sCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KyboColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
        title: Text(
          'Timer personalizzato',
          style: TextStyle(
            color: KyboColors.textPrimary(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: mCtrl,
                keyboardType: TextInputType.number,
                maxLength: 3,
                style: TextStyle(color: KyboColors.textPrimary(context), fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  counterText: '',
                  labelText: 'Min',
                  labelStyle: TextStyle(color: KyboColors.textSecondary(context)),
                  border: OutlineInputBorder(borderRadius: KyboBorderRadius.medium),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(':', style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: TextField(
                controller: sCtrl,
                keyboardType: TextInputType.number,
                maxLength: 2,
                style: TextStyle(color: KyboColors.textPrimary(context), fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  counterText: '',
                  labelText: 'Sec',
                  labelStyle: TextStyle(color: KyboColors.textSecondary(context)),
                  border: OutlineInputBorder(borderRadius: KyboBorderRadius.medium),
                ),
              ),
            ),
          ],
        ),
        actions: [
          PillButton(
            label: 'Annulla',
            onPressed: () => Navigator.pop(ctx),
            backgroundColor: KyboColors.surface(context),
            textColor: KyboColors.textPrimary(context),
            height: 40,
          ),
          PillButton(
            label: 'Imposta',
            onPressed: () {
              final m = int.tryParse(mCtrl.text) ?? 0;
              final s = int.tryParse(sCtrl.text) ?? 0;
              final total = m * 60 + s;
              if (total > 0) _setPreset(total);
              Navigator.pop(ctx);
            },
            backgroundColor: KyboColors.primary,
            textColor: Colors.white,
            height: 40,
          ),
        ],
      ),
    );
  }

  // --- Build ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KyboColors.background(context),
      appBar: AppBar(
        backgroundColor: KyboColors.surface(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: KyboColors.textPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Timer Cottura',
          style: TextStyle(
            color: KyboColors.textPrimary(context),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),

            // --- Circular progress + time display ---
            Center(
              child: SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background circle
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: 1,
                        strokeWidth: 10,
                        color: KyboColors.border(context),
                      ),
                    ),
                    // Progress arc
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: _progress,
                        strokeWidth: 10,
                        color: _finished
                            ? KyboColors.error
                            : KyboColors.primary,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    // Time text
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (_, __) {
                            final scale = _running && !_finished
                                ? 1.0 + _pulseController.value * 0.03
                                : 1.0;
                            return Transform.scale(
                              scale: scale,
                              child: Text(
                                _totalSeconds == 0 ? '--:--' : _displayTime,
                                style: TextStyle(
                                  color: _finished
                                      ? KyboColors.error
                                      : KyboColors.textPrimary(context),
                                  fontSize: 48,
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            );
                          },
                        ),
                        if (_finished)
                          Text(
                            '⏰ Pronto!',
                            style: TextStyle(
                              color: KyboColors.error,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // --- Preset buttons ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  ..._presets.map((p) => GestureDetector(
                    onTap: () => _setPreset(p.seconds),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: _totalSeconds == p.seconds
                            ? KyboColors.primary.withValues(alpha: 0.2)
                            : KyboColors.surface(context),
                        border: Border.all(
                          color: _totalSeconds == p.seconds
                              ? KyboColors.primary
                              : KyboColors.border(context),
                          width: _totalSeconds == p.seconds ? 2 : 1,
                        ),
                        borderRadius: KyboBorderRadius.pill,
                      ),
                      child: Text(
                        p.label,
                        style: TextStyle(
                          color: _totalSeconds == p.seconds
                              ? KyboColors.primary
                              : KyboColors.textSecondary(context),
                          fontWeight: _totalSeconds == p.seconds
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )),
                  // Custom button
                  GestureDetector(
                    onTap: _showCustomDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: KyboColors.surface(context),
                        border: Border.all(color: KyboColors.border(context)),
                        borderRadius: KyboBorderRadius.pill,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, size: 14, color: KyboColors.textSecondary(context)),
                          const SizedBox(width: 6),
                          Text(
                            'Personalizza',
                            style: TextStyle(
                              color: KyboColors.textSecondary(context),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // --- Controls ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Reset button
                  IconButton(
                    onPressed: _totalSeconds == 0 ? null : _reset,
                    icon: Icon(
                      Icons.replay_rounded,
                      size: 32,
                      color: _totalSeconds == 0
                          ? KyboColors.border(context)
                          : KyboColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Play/Pause button
                  GestureDetector(
                    onTap: _startPause,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _totalSeconds == 0
                            ? LinearGradient(colors: [
                                KyboColors.border(context),
                                KyboColors.border(context)
                              ])
                            : const LinearGradient(
                                colors: [Color(0xFF66BB6A), Color(0xFF2E7D32)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        boxShadow: _totalSeconds > 0
                            ? [
                                BoxShadow(
                                  color: KyboColors.primary.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                )
                              ]
                            : null,
                      ),
                      child: Icon(
                        _finished
                            ? Icons.replay_rounded
                            : (_running ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),

                  const SizedBox(width: 24),
                  // Spacer (simmetria)
                  const SizedBox(width: 48),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
