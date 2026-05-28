// SmoothScroll — smooth scroll "alla Lenis" per Flutter web.
//
// Di default su web la rotella muove lo scroll a scatti. Le librerie JS come
// Lenis / Locomotive (usate anche sul sito Kybo via GSAP) danno invece quel
// feeling fluido e "pesante" con un loop continuo: ad ogni frame la posizione
// corrente fa lerp verso un target, che la rotella aggiorna. La posizione
// "insegue" il target con easing esponenziale → movimento continuo e morbido,
// non una serie di animazioni discrete.
//
// Questo widget replica quel comportamento:
// - mantiene un `_target` aggiornato dagli eventi rotella
// - un Ticker (un tick per frame) avvicina la posizione corrente al target
//   con un fattore esponenziale time-based (framerate-independent)
// - drag / scrollbar / fling restano nativi; solo la rotella è "guidata".
//
// USO:
//   SmoothScroll(
//     builder: (context, controller) => SingleChildScrollView(
//       controller: controller,
//       child: ...,
//     ),
//   )

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class SmoothScroll extends StatefulWidget {
  /// Costruisce lo scrollable usando il [ScrollController] fornito.
  final Widget Function(BuildContext context, ScrollController controller)
      builder;

  /// "Rigidità" del lerp: più alto = insegue il target più velocemente
  /// (meno "pesante"), più basso = più morbido e fluttuante.
  /// ~10 è un buon valore "Lenis-like". Range utile ~6 (molto soft) – 16 (snappy).
  final double stiffness;

  /// Moltiplicatore del delta di rotella. >1 = ogni rotellata copre più spazio.
  final double speedFactor;

  const SmoothScroll({
    super.key,
    required this.builder,
    this.stiffness = 10.0,
    this.speedFactor = 1.0,
  });

  @override
  State<SmoothScroll> createState() => _SmoothScrollState();
}

class _SmoothScrollState extends State<SmoothScroll>
    with SingleTickerProviderStateMixin {
  final ScrollController _controller = ScrollController();
  late final Ticker _ticker;

  double _target = 0;
  bool _hasTarget = false;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!_controller.hasClients) {
      _stop();
      return;
    }

    final dtMicros = (elapsed - _lastElapsed).inMicroseconds;
    _lastElapsed = elapsed;
    // Primo tick (dt enorme/0): salta, aspetta il prossimo per un dt valido.
    if (dtMicros <= 0) return;
    final dt = dtMicros / 1e6; // secondi

    final current = _controller.offset;
    final diff = _target - current;

    // Arrivati: aggancia esatto e ferma il loop.
    if (diff.abs() < 0.5) {
      _controller.jumpTo(_target);
      _stop();
      return;
    }

    // Lerp esponenziale framerate-independent:
    //   factor = 1 - e^(-stiffness * dt)
    // a 60fps con stiffness=10 → ~15% per frame.
    final factor = 1 - math.exp(-widget.stiffness * dt);
    final next = current + diff * factor;

    final min = _controller.position.minScrollExtent;
    final max = _controller.position.maxScrollExtent;
    _controller.jumpTo(next.clamp(min, max));
  }

  void _stop() {
    if (_ticker.isActive) _ticker.stop();
    _hasTarget = false;
    _lastElapsed = Duration.zero;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (!_controller.hasClients) return;

    // Claim dell'evento: impedisce allo scrollable nativo di gestire ANCHE
    // lui la rotella (eviterebbe doppio scroll).
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      if (!_controller.hasClients) return;

      final min = _controller.position.minScrollExtent;
      final max = _controller.position.maxScrollExtent;

      // Base = il target in volo se stiamo già scorrendo, altrimenti la
      // posizione reale corrente (così rotellate rapide si accumulano).
      final base = _hasTarget ? _target : _controller.offset;
      final delta = event.scrollDelta.dy * widget.speedFactor;
      _target = (base + delta).clamp(min, max);
      _hasTarget = true;

      if (!_ticker.isActive) {
        _lastElapsed = Duration.zero;
        _ticker.start();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: widget.builder(context, _controller),
    );
  }
}
