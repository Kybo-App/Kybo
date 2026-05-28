// Pagina demo isolata per testare CascadeStripSlicer.
//
// Mostra un contenuto colorato (strisce orizzontali + un blocco che
// attraversa più strip) e un pulsante che lancia la cascata. Serve a
// vedere l'effetto "onda" del slicing prima di integrarlo nel dashboard.
//
// Per provarla: punta temporaneamente il widget home a CascadeDemoScreen,
// oppure aggiungi una route. È completamente self-contained.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../widgets/cascade_strip_slicer.dart';

class CascadeDemoScreen extends StatefulWidget {
  const CascadeDemoScreen({super.key});

  @override
  State<CascadeDemoScreen> createState() => _CascadeDemoScreenState();
}

class _CascadeDemoScreenState extends State<CascadeDemoScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  // Parametri cascata (stessi del dashboard reale)
  static const double _stripHeight = 52; // altezza tab (per la cascade math)
  static const double _sliceHeight = 12; // granularità slicing fine (sfuma)
  static const int _staggerMs = 80;
  static const int _itemAnimMs = 320;
  static const double _maxPush = 168; // 240 - 72 (sidebar expanded - collapsed)

  // Strip "selezionata" da cui parte l'onda.
  int _selectedStrip = 3;

  // Quante strip totali (incluse phantom)
  final int _numStrips = 14;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Duration _computeDuration() {
    final maxDist =
        math.max(_selectedStrip, _numStrips - 1 - _selectedStrip);
    return Duration(milliseconds: maxDist * _staggerMs + _itemAnimMs);
  }

  void _expand() {
    _anim.duration = _computeDuration();
    _anim.forward();
  }

  void _collapse() {
    _anim.duration = _computeDuration();
    _anim.reverse();
  }

  /// Offset orizzontale CONTINUO data una Y (in px). La "distanza" dalla
  /// strip selezionata è calcolata in modo continuo (Y/altezzaStrip), così
  /// l'offset varia con continuità e l'onda è liscia invece che a scalini.
  double _offsetAtY(double centerY, double globalT, int totalMs) {
    final stripFloat = centerY / _stripHeight;
    final distance = (stripFloat - _selectedStrip).abs();
    final delayMs = distance * _staggerMs;
    final elapsedMs = globalT * totalMs;
    final localT = ((elapsedMs - delayMs) / _itemAnimMs).clamp(0.0, 1.0);
    final eased = Curves.easeInOut.transform(localT);
    return _maxPush * eased;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Cascade Slicer Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.unfold_less),
            tooltip: 'Collassa',
            onPressed: _collapse,
          ),
          IconButton(
            icon: const Icon(Icons.unfold_more),
            tooltip: 'Espandi cascata',
            onPressed: _expand,
          ),
        ],
      ),
      body: Column(
        children: [
          // Selettore strip selezionata
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Text('Strip selezionata: '),
                Expanded(
                  child: Slider(
                    value: _selectedStrip.toDouble(),
                    min: 0,
                    max: (_numStrips - 1).toDouble(),
                    divisions: _numStrips - 1,
                    label: '$_selectedStrip',
                    onChanged: (v) =>
                        setState(() => _selectedStrip = v.round()),
                  ),
                ),
                Text('$_selectedStrip'),
              ],
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context, _) {
                final globalT = _anim.value;
                final totalMs = _anim.duration?.inMilliseconds ??
                    _computeDuration().inMilliseconds;

                return CascadeStripSlicer(
                  sliceHeight: _sliceHeight,
                  repaintTick: globalT,
                  offsetAt: (centerY) =>
                      _offsetAtY(centerY, globalT, totalMs),
                  child: _DemoContent(
                    stripHeight: _stripHeight,
                    numStrips: _numStrips,
                    selectedStrip: _selectedStrip,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Contenuto demo: strisce orizzontali colorate (così ogni strip è
/// distinguibile) + un blocco "card" che attraversa più strip (per vedere
/// come viene affettato durante l'animazione).
class _DemoContent extends StatelessWidget {
  final double stripHeight;
  final int numStrips;
  final int selectedStrip;

  const _DemoContent({
    required this.stripHeight,
    required this.numStrips,
    required this.selectedStrip,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Strisce orizzontali colorate (1 per strip)
        Column(
          children: List.generate(numStrips, (i) {
            final hue = (i * 28) % 360;
            final isSelected = i == selectedStrip;
            return Container(
              height: stripHeight,
              color: HSLColor.fromAHSL(
                isSelected ? 0.55 : 0.30,
                hue.toDouble(),
                0.7,
                0.6,
              ).toColor(),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                isSelected ? 'STRIP $i (selezionata)' : 'strip $i',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight:
                      isSelected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            );
          }),
        ),
        // Card che attraversa più strip (per testare lo slicing su un
        // elemento più alto di una strip).
        Positioned(
          left: 280,
          top: stripHeight * 1.5,
          child: Container(
            width: 220,
            height: stripHeight * 3,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              'Card alta 3 strip\n(verrà affettata\ndurante la cascata)',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
