// CascadeStripSlicer — affetta il proprio child in fasce orizzontali e dipinge
// ognuna traslata orizzontalmente di una quantità che dipende dalla sua Y,
// secondo una funzione continua. Serve all'effetto "cascata": durante
// l'animazione ogni riga Y della pagina viene spinta a destra in base alla
// distanza dalla tab selezionata → onda che attraversa la pagina.
//
// APPROCCIO A SNAPSHOT (texture):
// Il content reale contiene layer di compositing (Opacity, ombre, ecc.).
// Ridipingerlo N volte (uno per fascia) non è possibile: un layer non può
// avere più genitori → il content sparirebbe. Quindi catturiamo il child
// in una ui.Image UNA volta (via SnapshotWidget) e disegniamo le fasce
// dell'immagine con drawImageRect — blit GPU economici, nessun problema di
// layer, e fasce sottili (sliceHeight piccolo) danno un'onda liscissima a
// costo quasi costante.
//
// - Quando l'animazione è ferma (idle): NON si fa snapshot → il child è
//   dipinto live e interattivo, con un eventuale offset uniforme (es. 168px
//   da sidebar espansa) applicato come semplice translate.
// - Quando l'animazione è in corso: snapshot + slicing. Il content non è
//   interattivo per quel ~1s, ma è solo hover quindi va bene.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class CascadeStripSlicer extends StatefulWidget {
  /// Altezza di ogni fascia di slicing (px). Più piccola = onda più liscia.
  final double sliceHeight;

  /// Funzione continua: dato il centro Y di una fascia (coord. locali),
  /// restituisce l'offset orizzontale (px verso destra) da applicare.
  final double Function(double centerY) offsetAt;

  /// Animazione che pilota la cascata. Usata per:
  /// - sapere quando fare snapshot (status running) vs live (idle)
  /// - forzare il repaint del painter ad ogni tick
  final Animation<double> animation;

  final Widget child;

  const CascadeStripSlicer({
    super.key,
    required this.sliceHeight,
    required this.offsetAt,
    required this.animation,
    required this.child,
  });

  @override
  State<CascadeStripSlicer> createState() => _CascadeStripSlicerState();
}

class _CascadeStripSlicerState extends State<CascadeStripSlicer> {
  final SnapshotController _snapshotController =
      SnapshotController(allowSnapshotting: false);
  late final _CascadeSnapshotPainter _painter;

  @override
  void initState() {
    super.initState();
    _painter = _CascadeSnapshotPainter(
      animation: widget.animation,
      offsetAt: widget.offsetAt,
      sliceHeight: widget.sliceHeight,
    );
    widget.animation.addStatusListener(_onStatus);
    // Stato iniziale: se l'animazione è già in movimento, abilita snapshot.
    _snapshotController.allowSnapshotting = widget.animation.isAnimating;
  }

  void _onStatus(AnimationStatus status) {
    final running = status == AnimationStatus.forward ||
        status == AnimationStatus.reverse;
    if (_snapshotController.allowSnapshotting != running) {
      _snapshotController.allowSnapshotting = running;
    }
  }

  @override
  void didUpdateWidget(CascadeStripSlicer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeStatusListener(_onStatus);
      widget.animation.addStatusListener(_onStatus);
    }
    _painter
      ..offsetAt = widget.offsetAt
      ..sliceHeight = widget.sliceHeight
      ..animation = widget.animation;
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_onStatus);
    _painter.dispose();
    _snapshotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SnapshotWidget(
      controller: _snapshotController,
      painter: _painter,
      child: widget.child,
    );
  }
}

class _CascadeSnapshotPainter extends SnapshotPainter {
  _CascadeSnapshotPainter({
    required Animation<double> animation,
    required double Function(double centerY) offsetAt,
    required double sliceHeight,
  })  : _animation = animation,
        _offsetAt = offsetAt,
        _sliceHeight = sliceHeight {
    _animation.addListener(notifyListeners);
  }

  Animation<double> _animation;
  set animation(Animation<double> value) {
    if (_animation == value) return;
    _animation.removeListener(notifyListeners);
    _animation = value;
    _animation.addListener(notifyListeners);
  }

  double Function(double centerY) _offsetAt;
  set offsetAt(double Function(double centerY) value) => _offsetAt = value;

  double _sliceHeight;
  set sliceHeight(double value) => _sliceHeight = value;

  /// Disegna l'immagine catturata del child in fasce orizzontali, ognuna
  /// traslata di `offsetAt(centerY)`. Usato DURANTE l'animazione.
  @override
  void paintSnapshot(
    PaintingContext context,
    Offset offset,
    Size size,
    ui.Image image,
    Size sourceSize,
    double pixelRatio,
  ) {
    final canvas = context.canvas;
    final paint = ui.Paint()..filterQuality = FilterQuality.low;
    final h = _sliceHeight <= 0 ? size.height : _sliceHeight;
    final numSlices = (size.height / h).ceil();

    for (int i = 0; i < numSlices; i++) {
      final y = i * h;
      final sliceH = math.min(h, size.height - y);
      if (sliceH <= 0) break;
      final dx = _offsetAt(y + sliceH / 2);

      // Sorgente: la fascia [y, y+sliceH] dell'immagine (in px immagine,
      // quindi moltiplicata per pixelRatio).
      final src = Rect.fromLTWH(
        0,
        y * pixelRatio,
        sourceSize.width * pixelRatio,
        sliceH * pixelRatio,
      );
      // Destinazione: stessa fascia ma spostata a destra di dx.
      final dst = Rect.fromLTWH(
        offset.dx + dx,
        offset.dy + y,
        sourceSize.width,
        sliceH,
      );
      canvas.drawImageRect(image, src, dst, paint);
    }
  }

  /// Dipinge il child LIVE (interattivo) quando NON si sta facendo snapshot
  /// (stato idle). Applica un offset uniforme se la cascata è "a riposo
  /// espanso" (tutte le fasce allo stesso X). In idle-collassato l'offset è 0.
  @override
  void paint(
    PaintingContext context,
    Offset offset,
    Size size,
    PaintingContextCallback painter,
  ) {
    final dx = _offsetAt(size.height / 2);
    painter(context, offset + Offset(dx, 0));
  }

  @override
  bool shouldRepaint(covariant _CascadeSnapshotPainter oldDelegate) {
    return oldDelegate._animation.value != _animation.value ||
        oldDelegate._sliceHeight != _sliceHeight ||
        oldDelegate._offsetAt != _offsetAt;
  }

  @override
  void dispose() {
    _animation.removeListener(notifyListeners);
    super.dispose();
  }
}
