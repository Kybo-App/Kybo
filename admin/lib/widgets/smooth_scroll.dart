// SmoothScroll — wrapper che rende fluido lo scroll a rotella su Flutter web.
//
// Di default su web la rotella del mouse muove lo scroll a "scatti": ogni
// notch salta di ~100px senza animazione, dando una sensazione a gradini.
// Questo wrapper intercetta l'evento PointerScroll, accumula la destinazione
// e fa `animateTo` con una curva di easing → scroll morbido e continuo.
//
// USO:
//   SmoothScroll(
//     builder: (context, controller) => SingleChildScrollView(
//       controller: controller,
//       child: ...,
//     ),
//   )
//
// Il builder DEVE passare il `controller` ricevuto allo scrollable, così
// SmoothScroll può animarne la posizione. Drag, scrollbar e fling continuano
// a funzionare normalmente (gestiti dallo scrollable nativo); solo la rotella
// viene "intercettata" e animata.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class SmoothScroll extends StatefulWidget {
  /// Costruisce lo scrollable usando il [ScrollController] fornito.
  final Widget Function(BuildContext context, ScrollController controller)
      builder;

  /// Durata dell'animazione per ogni "passo" di rotella.
  final Duration duration;

  /// Curva di easing dell'animazione.
  final Curve curve;

  /// Moltiplicatore del delta di rotella. >1 scrolla più velocemente.
  final double speedFactor;

  const SmoothScroll({
    super.key,
    required this.builder,
    this.duration = const Duration(milliseconds: 220),
    this.curve = Curves.easeOutCubic,
    this.speedFactor = 1.0,
  });

  @override
  State<SmoothScroll> createState() => _SmoothScrollState();
}

class _SmoothScrollState extends State<SmoothScroll> {
  final ScrollController _controller = ScrollController();
  double _targetOffset = 0;
  bool _animating = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (!_controller.hasClients) return;

    // Claim dell'evento tramite il resolver: impedisce allo scrollable
    // nativo di gestire ANCHE lui la rotella (eviterebbe doppio scroll).
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      if (!_controller.hasClients) return;

      final position = _controller.position;
      final maxExtent = position.maxScrollExtent;
      final minExtent = position.minScrollExtent;

      // Se non stiamo già animando, parti dalla posizione corrente reale.
      final base = _animating ? _targetOffset : _controller.offset;
      final delta = event.scrollDelta.dy * widget.speedFactor;
      _targetOffset = (base + delta).clamp(minExtent, maxExtent);

      // Niente da fare se siamo già al limite.
      if ((_targetOffset - _controller.offset).abs() < 0.5) return;

      _animating = true;
      _controller
          .animateTo(
            _targetOffset,
            duration: widget.duration,
            curve: widget.curve,
          )
          .whenComplete(() => _animating = false);
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
