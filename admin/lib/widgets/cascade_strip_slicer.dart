// CascadeStripSlicer — widget custom che "affetta" il proprio child in strip
// orizzontali di altezza fissa e dipinge ognuna traslata orizzontalmente di
// una quantità diversa.
//
// Serve per l'effetto "cascata sidebar": durante l'animazione, ogni riga Y
// della pagina viene spinta a destra di una quantità che dipende dalla sua
// distanza dalla tab selezionata. Il risultato è un'onda che attraversa la
// pagina, perché strip a Y diverse sono a stadi diversi dell'animazione.
//
// Implementazione: il child viene laid-out UNA volta alla sua dimensione
// naturale. In fase di paint, per ogni strip:
//   1. clip al rettangolo destinazione (Y della strip, X spostato di offset)
//   2. dipinge il child traslato orizzontalmente di `offset`
// Solo la fascia Y della strip è visibile grazie al clip.
//
// NB: il child viene dipinto N volte (N = numero di strip). Per contenuti
// moderatamente complessi va bene perché il paint avviene solo durante
// l'animazione (~1s), poi tutte le strip hanno lo stesso offset e l'effetto
// è statico. IMPORTANTE: il child NON deve essere un RepaintBoundary né
// contenerne ai livelli alti, altrimenti il layer verrebbe agganciato a più
// genitori (non permesso da Flutter).

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class CascadeStripSlicer extends SingleChildRenderObjectWidget {
  /// Altezza di ogni strip in px (tipicamente = altezza di una tab sidebar).
  final double stripHeight;

  /// Offset orizzontale (px verso destra) per ogni strip, indicizzato per
  /// numero di strip dall'alto (0 = prima strip). Se la lista è più corta del
  /// numero di strip rese, le strip eccedenti usano l'ultimo valore.
  final List<double> offsets;

  const CascadeStripSlicer({
    super.key,
    required this.stripHeight,
    required this.offsets,
    required Widget super.child,
  });

  @override
  RenderCascadeStripSlicer createRenderObject(BuildContext context) {
    return RenderCascadeStripSlicer(
      stripHeight: stripHeight,
      offsets: offsets,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderCascadeStripSlicer renderObject) {
    renderObject
      ..stripHeight = stripHeight
      ..offsets = offsets;
  }
}

class RenderCascadeStripSlicer extends RenderProxyBox {
  RenderCascadeStripSlicer({
    required double stripHeight,
    required List<double> offsets,
  })  : _stripHeight = stripHeight,
        _offsets = offsets;

  double _stripHeight;
  double get stripHeight => _stripHeight;
  set stripHeight(double value) {
    if (_stripHeight == value) return;
    _stripHeight = value;
    markNeedsPaint();
  }

  List<double> _offsets;
  List<double> get offsets => _offsets;
  set offsets(List<double> value) {
    if (listEquals(_offsets, value)) return;
    _offsets = value;
    markNeedsPaint();
  }

  // Layer di clip riutilizzati tra i frame (uno per strip) per efficienza.
  final List<ClipRectLayer?> _clipLayers = [];

  double _offsetForStrip(int i) {
    if (_offsets.isEmpty) return 0.0;
    if (i < _offsets.length) return _offsets[i];
    return _offsets.last;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;

    final h = _stripHeight;
    // Fallback: senza strip valide, dipingi normalmente.
    if (h <= 0 || size.height <= 0) {
      context.paintChild(child, offset);
      return;
    }

    final numStrips = (size.height / h).ceil();

    // Adatta la lista di clip layer al numero di strip corrente.
    while (_clipLayers.length < numStrips) {
      _clipLayers.add(null);
    }
    while (_clipLayers.length > numStrips) {
      _clipLayers.removeLast();
    }

    for (int i = 0; i < numStrips; i++) {
      final stripTop = i * h;
      final dx = _offsetForStrip(i);

      // Clip al rettangolo destinazione: la fascia Y della strip, partendo
      // da X = dx (dove appare il contenuto spostato).
      final clipRect = Rect.fromLTWH(dx, stripTop, size.width, h);

      _clipLayers[i] = context.pushClipRect(
        needsCompositing,
        offset,
        clipRect,
        (PaintingContext innerCtx, Offset innerOffset) {
          // Dipingi il child spostato a destra di dx. Solo la fascia Y
          // della strip è visibile grazie al clip sopra.
          innerCtx.paintChild(child, innerOffset + Offset(dx, 0));
        },
        oldLayer: _clipLayers[i],
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;

    final h = _stripHeight;
    if (h <= 0) {
      return super.hitTestChildren(result, position: position);
    }

    // Trova la strip che contiene la Y del puntatore e inverti il suo offset
    // orizzontale per il hit test (così i click finiscono sull'elemento
    // visivamente cliccato anche durante l'animazione).
    final stripIdx = (position.dy / h).floor();
    final dx = _offsetForStrip(stripIdx);

    return result.addWithPaintOffset(
      offset: Offset(dx, 0),
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) {
        return child.hitTest(result, position: transformed);
      },
    );
  }
}
