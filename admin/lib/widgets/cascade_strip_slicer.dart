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

    // Overlap verticale tra strisce: copre eventuali hairline (gap sub-pixel)
    // ai bordi shearati. Tenuto a 1px → disallineamento impercettibile.
    const overlap = 1.0;
    // [PERF] Tolleranza (px) sotto cui due offset sono considerati uguali:
    // usata per fondere fasce "piatte" consecutive in un unico blit.
    const eps = 0.02;

    double y = 0;
    double dxTop = _offsetAt(0);
    while (y < size.height) {
      double sliceH = math.min(h, size.height - y);

      // Offset orizzontale al bordo SUPERIORE e INFERIORE della fascia.
      // Disegnando la striscia come parallelogramma (shear lineare tra i due),
      // il suo bordo basso combacia col bordo alto della striscia successiva
      // → i lati del contenuto diventano una linea continua, non una scaletta.
      double dxBottom = _offsetAt(y + sliceH);

      // [PERF] MERGE delle fasce piatte: nelle zone dove l'onda è ferma
      // (contenuto già spinto a maxPush, o non ancora raggiunto dall'onda:
      // offset costante) fasce adiacenti identiche vengono fuse in un'unica
      // striscia → 1 drawImageRect invece di decine. Con viewport ~900px e
      // sliceHeight 6 si passa da ~150 draw/frame a poche decine nei frame
      // centrali e a ~3-5 in quelli iniziali/finali. Il midpoint check evita
      // di fondere una fascia che contiene il "fold" dell'onda al suo interno
      // (endpoint uguali ma interno diverso, possibile attorno alla tab
      // selezionata nei primissimi frame).
      if ((dxBottom - dxTop).abs() < eps &&
          (_offsetAt(y + sliceH / 2) - dxTop).abs() < eps) {
        var yEnd = y + sliceH;
        while (yEnd < size.height) {
          final step = math.min(h, size.height - yEnd);
          if ((_offsetAt(yEnd + step) - dxTop).abs() >= eps ||
              (_offsetAt(yEnd + step / 2) - dxTop).abs() >= eps) {
            break;
          }
          yEnd += step;
        }
        sliceH = yEnd - y;
        dxBottom = dxTop; // piatta per costruzione
      }

      // Estende la fascia di `overlap` px in basso (clampato all'immagine).
      final drawH = math.min(sliceH + overlap, sourceSize.height - y);

      final src = Rect.fromLTWH(
        0,
        y * pixelRatio,
        sourceSize.width * pixelRatio,
        drawH * pixelRatio,
      );
      // Destinazione SENZA offset orizzontale: lo spostamento viene applicato
      // dalla matrice di shear qui sotto.
      final dst = Rect.fromLTWH(
        offset.dx,
        offset.dy + y,
        sourceSize.width,
        drawH,
      );

      // Shear in X funzione di Y: x' = x + k*y + tx, con
      //   k  = (dxBottom - dxTop) / sliceH   (pendenza dell'onda nella fascia)
      //   tx = dxTop - k*y0                  (al bordo alto → x' = x + dxTop)
      final y0 = offset.dy + y;
      final k = (dxBottom - dxTop) / sliceH;
      final tx = dxTop - k * y0;
      final m = Matrix4.identity()
        ..setEntry(0, 1, k)
        ..setEntry(0, 3, tx);

      canvas.save();
      // Clip alla banda ESATTA [y0, y0+sliceH] (lo shear è solo orizzontale,
      // quindi la Y non cambia): l'`overlap` riempie i gap sub-pixel ai bordi
      // inclinati ma la sua parte eccedente viene tagliata → nessuna doppia
      // composizione, quindi niente righe scure che attraversano la pagina.
      // [FIX hairline] doAntiAlias: false — il clip AA su bordi a coordinate
      // frazionarie (es. Windows a scala 125%: 6px logici = 7.5px fisici)
      // lascia pixel di bordo semi-trasparenti su ENTRAMBE le fasce che si
      // incontrano → la doppia composizione non torna opaca al 100% e appare
      // una riga orizzontale. Il clip hard scatta al pixel fisico intero:
      // ogni pixel appartiene a una sola fascia e l'overlap copre i buchi.
      canvas.clipRect(
        Rect.fromLTWH(
          offset.dx - 1,
          y0,
          sourceSize.width + 2000,
          sliceH,
        ),
        doAntiAlias: false,
      );
      canvas.transform(m.storage);
      canvas.drawImageRect(image, src, dst, paint);
      canvas.restore();

      y += sliceH;
      dxTop = dxBottom;
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
