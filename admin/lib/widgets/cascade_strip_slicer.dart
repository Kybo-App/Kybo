// CascadeStripSlicer — widget custom che "affetta" il proprio child in fasce
// orizzontali e dipinge ognuna traslata orizzontalmente di una quantità che
// dipende dalla sua posizione Y, secondo una funzione continua.
//
// Serve per l'effetto "cascata sidebar": durante l'animazione, ogni riga Y
// della pagina viene spinta a destra di una quantità che dipende dalla sua
// distanza dalla tab selezionata. Il risultato è un'onda che attraversa la
// pagina.
//
// SFUMATURA: invece di affettare all'altezza della tab (52px → scalini netti),
// affettiamo a granularità fine (`sliceHeight`, default ~12px) e calcoliamo
// l'offset di ogni fascia tramite `offsetAt(centerY)` — una funzione continua.
// Con fasce sottili + funzione continua, l'onda appare come una curva liscia
// invece che a gradini, "sfumando" il taglio tra una fascia e l'altra.
//
// Implementazione: il child viene laid-out UNA volta. In paint, per ogni
// fascia: clip alla fascia destinazione + dipinge il child traslato di dx.
//
// VINCOLO: il child NON deve essere un RepaintBoundary (né contenerne ai
// livelli alti), perché viene ridipinto N volte e un layer non può avere
// più genitori. Il paint multiplo avviene solo durante l'animazione.

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class CascadeStripSlicer extends SingleChildRenderObjectWidget {
  /// Altezza di ogni fascia di slicing in px. Più piccola = onda più liscia
  /// ma più paint per frame. ~12px è un buon compromesso.
  final double sliceHeight;

  /// Funzione continua: dato il centro Y di una fascia (in coordinate locali),
  /// restituisce l'offset orizzontale (px verso destra) da applicare.
  final double Function(double centerY) offsetAt;

  /// Valore che cambia ad ogni frame dell'animazione (es. controller.value).
  /// Forza il re-paint del RenderObject quando l'animazione avanza.
  final double repaintTick;

  const CascadeStripSlicer({
    super.key,
    required this.sliceHeight,
    required this.offsetAt,
    required this.repaintTick,
    required Widget super.child,
  });

  @override
  RenderCascadeStripSlicer createRenderObject(BuildContext context) {
    return RenderCascadeStripSlicer(
      sliceHeight: sliceHeight,
      offsetAt: offsetAt,
      repaintTick: repaintTick,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderCascadeStripSlicer renderObject) {
    renderObject
      ..sliceHeight = sliceHeight
      ..offsetAt = offsetAt
      ..repaintTick = repaintTick;
  }
}

class RenderCascadeStripSlicer extends RenderProxyBox {
  RenderCascadeStripSlicer({
    required double sliceHeight,
    required double Function(double centerY) offsetAt,
    required double repaintTick,
  })  : _sliceHeight = sliceHeight,
        _offsetAt = offsetAt,
        _repaintTick = repaintTick;

  double _sliceHeight;
  double get sliceHeight => _sliceHeight;
  set sliceHeight(double value) {
    if (_sliceHeight == value) return;
    _sliceHeight = value;
    markNeedsPaint();
  }

  double Function(double centerY) _offsetAt;
  double Function(double centerY) get offsetAt => _offsetAt;
  set offsetAt(double Function(double centerY) value) {
    _offsetAt = value;
    markNeedsPaint();
  }

  double _repaintTick;
  double get repaintTick => _repaintTick;
  set repaintTick(double value) {
    if (_repaintTick == value) return;
    _repaintTick = value;
    markNeedsPaint();
  }

  // Layer di clip riutilizzati tra i frame (uno per fascia) per efficienza.
  final List<ClipRectLayer?> _clipLayers = [];

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;

    final h = _sliceHeight;
    if (h <= 0 || size.height <= 0) {
      context.paintChild(child, offset);
      return;
    }

    final numSlices = (size.height / h).ceil();

    // Ottimizzazione: se tutte le fasce hanno (praticamente) lo stesso offset
    // — caso idle, animazione ferma — dipingiamo il child una volta sola con
    // un singolo translate, evitando N paint.
    final firstOffset = _offsetAt(h / 2);
    bool uniform = true;
    for (int i = 1; i < numSlices; i++) {
      final o = _offsetAt(i * h + h / 2);
      if ((o - firstOffset).abs() > 0.5) {
        uniform = false;
        break;
      }
    }
    if (uniform) {
      _clipLayers.clear();
      context.paintChild(child, offset + Offset(firstOffset, 0));
      return;
    }

    while (_clipLayers.length < numSlices) {
      _clipLayers.add(null);
    }
    while (_clipLayers.length > numSlices) {
      _clipLayers.removeLast();
    }

    for (int i = 0; i < numSlices; i++) {
      final sliceTop = i * h;
      final sliceH =
          (sliceTop + h > size.height) ? size.height - sliceTop : h;
      final dx = _offsetAt(sliceTop + sliceH / 2);

      final clipRect = Rect.fromLTWH(dx, sliceTop, size.width, sliceH);

      _clipLayers[i] = context.pushClipRect(
        needsCompositing,
        offset,
        clipRect,
        (PaintingContext innerCtx, Offset innerOffset) {
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

    final h = _sliceHeight;
    if (h <= 0) {
      return super.hitTestChildren(result, position: position);
    }

    // Inverti l'offset orizzontale della fascia che contiene la Y del puntatore.
    final dx = _offsetAt(position.dy);

    return result.addWithPaintOffset(
      offset: Offset(dx, 0),
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) {
        return child.hitTest(result, position: transformed);
      },
    );
  }
}
