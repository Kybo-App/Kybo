// Genera un report PDF per cliente (cronologia diete + workout + note interne).
// Pattern: stesso approccio di reports_view.dart (pdf package + universal_html
// blob download). Tutto lato client per evitare carico server.

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_html/html.dart' as html;
import '../admin_repository.dart';

class ClientReportService {
  final AdminRepository _repo;
  final FirebaseFirestore _firestore;

  ClientReportService({AdminRepository? repo, FirebaseFirestore? firestore})
      : _repo = repo ?? AdminRepository(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Genera e fa scaricare il report PDF per il cliente specificato.
  /// Lancia exception in caso di errore (chi chiama mostra snackbar).
  Future<void> generateAndDownload({
    required String clientUid,
    required Map<String, dynamic> clientData,
  }) async {
    // Raccolta dati in parallelo dove possibile.
    final results = await Future.wait([
      _safeFetchHistory(clientUid),
      _safeFetchNotes(clientUid),
      _fetchWorkoutCompletions(clientUid),
    ]);
    final dietHistory = results[0];
    final notes = results[1];
    final completions = results[2] as List<Map<String, dynamic>>;

    final pdf = _buildPdf(
      clientData: clientData,
      dietHistory: dietHistory,
      notes: notes,
      completions: completions,
    );

    final bytes = await pdf.save();
    final blob = html.Blob([Uint8List.fromList(bytes)], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final firstName = (clientData['first_name'] ?? '').toString();
    final lastName = (clientData['last_name'] ?? '').toString();
    final safeName = '${firstName}_$lastName'.replaceAll(' ', '_');
    final stamp = DateFormat('yyyyMMdd').format(DateTime.now());
    final fileName = 'report_${safeName.isEmpty ? clientUid.substring(0, 6) : safeName}_$stamp.pdf';

    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();

    html.Url.revokeObjectUrl(url);
  }

  Future<List<dynamic>> _safeFetchHistory(String uid) async {
    try {
      return await _repo.getSecureUserHistory(uid);
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> _safeFetchNotes(String uid) async {
    try {
      return await _repo.getClientNotes(uid);
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchWorkoutCompletions(
      String uid) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('workout_completions')
          .orderBy('completed_at', descending: true)
          .limit(30)
          .get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (_) {
      return [];
    }
  }

  pw.Document _buildPdf({
    required Map<String, dynamic> clientData,
    required List<dynamic> dietHistory,
    required List<dynamic> notes,
    required List<Map<String, dynamic>> completions,
  }) {
    final pdf = pw.Document();
    final name = "${clientData['first_name'] ?? ''} ${clientData['last_name'] ?? ''}".trim();
    final email = (clientData['email'] ?? '').toString();
    final role = (clientData['role'] ?? '').toString();
    final createdAt = clientData['created_at']?.toString();
    final lastSeen = (clientData['last_seen'] ?? clientData['last_login'])?.toString();
    final lastDiet = clientData['last_diet_update']?.toString();

    // Stats workout
    final feedbackCount = <String, int>{'easy': 0, 'ok': 0, 'hard': 0};
    for (final c in completions) {
      final f = c['feedback']?.toString();
      if (f != null && feedbackCount.containsKey(f)) {
        feedbackCount[f] = feedbackCount[f]! + 1;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (ctx) => ctx.pageNumber == 1
            ? pw.SizedBox.shrink()
            : pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Text(
                  'Kybo — Report cliente${name.isNotEmpty ? ': $name' : ''}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            'Pagina ${ctx.pageNumber}/${ctx.pagesCount}  ·  Generato il ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
          ),
        ),
        build: (pw.Context context) => [
          // --- HEADER ---
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Kybo — Report Cliente',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    name.isEmpty ? email : name,
                    style: const pw.TextStyle(fontSize: 16),
                  ),
                  if (email.isNotEmpty && name.isNotEmpty)
                    pw.Text(
                      email,
                      style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.grey700,
                      ),
                    ),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blueGrey100,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Text(
                  role.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey800,
                  ),
                ),
              ),
            ],
          ),
          pw.Divider(thickness: 2),
          pw.SizedBox(height: 16),

          // --- INFO BASE ---
          pw.Text('Informazioni generali',
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: const {
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(2),
            },
            children: [
              _infoRow('Email', email.isEmpty ? '-' : email),
              _infoRow('Ruolo', role.isEmpty ? '-' : role),
              _infoRow('Account creato', _fmtDate(createdAt)),
              _infoRow('Ultima attività', _fmtDate(lastSeen)),
              _infoRow('Ultima dieta caricata', _fmtDate(lastDiet)),
            ],
          ),
          pw.SizedBox(height: 20),

          // --- STORICO DIETE ---
          pw.Text('Storico diete (${dietHistory.length})',
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (dietHistory.isEmpty)
            pw.Text('Nessuna dieta caricata.',
                style: const pw.TextStyle(
                    fontSize: 11, color: PdfColors.grey600))
          else
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
              cellPadding: const pw.EdgeInsets.all(6),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headers: const ['Data', 'Nome file', 'ID'],
              data: dietHistory.map((d) {
                final m = d as Map<String, dynamic>;
                return [
                  _fmtDate(m['uploadedAt']?.toString()),
                  (m['fileName'] ?? '-').toString(),
                  ((m['id'] ?? '').toString().isEmpty)
                      ? '-'
                      : (m['id'] as String).substring(
                          0,
                          (m['id'] as String).length > 8
                              ? 8
                              : (m['id'] as String).length,
                        ),
                ];
              }).toList(),
            ),
          pw.SizedBox(height: 20),

          // --- WORKOUT COMPLETIONS ---
          pw.Text('Workout — ultimi ${completions.length} completamenti',
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _statBox('Facili', '${feedbackCount['easy']}'),
              pw.SizedBox(width: 8),
              _statBox('Ok', '${feedbackCount['ok']}'),
              pw.SizedBox(width: 8),
              _statBox('Duri', '${feedbackCount['hard']}'),
              pw.SizedBox(width: 8),
              _statBox('Totale', '${completions.length}'),
            ],
          ),
          pw.SizedBox(height: 12),
          if (completions.isEmpty)
            pw.Text('Nessun workout completato.',
                style: const pw.TextStyle(
                    fontSize: 11, color: PdfColors.grey600))
          else
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
              cellPadding: const pw.EdgeInsets.all(6),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headers: const ['Data', 'Feedback', 'Note'],
              data: completions.map((c) {
                final ts = c['completed_at'];
                String dateStr = '-';
                if (ts is Timestamp) {
                  dateStr = DateFormat('dd/MM/yyyy').format(ts.toDate());
                } else if (ts != null) {
                  final dt = DateTime.tryParse(ts.toString());
                  if (dt != null) {
                    dateStr = DateFormat('dd/MM/yyyy').format(dt);
                  }
                }
                return [
                  dateStr,
                  _feedbackLabel(c['feedback']?.toString()),
                  (c['feedback_note'] ?? '').toString(),
                ];
              }).toList(),
            ),
          pw.SizedBox(height: 20),

          // --- NOTE INTERNE ---
          pw.Text('Note interne (${notes.length})',
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (notes.isEmpty)
            pw.Text('Nessuna nota interna.',
                style: const pw.TextStyle(
                    fontSize: 11, color: PdfColors.grey600))
          else
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: notes.map<pw.Widget>((n) {
                final m = n as Map<String, dynamic>;
                final cat = (m['category'] ?? 'general').toString();
                final created = _fmtDate(m['created_at']?.toString());
                final content = (m['content'] ?? '').toString();
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment:
                            pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            cat.toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blueGrey700,
                            ),
                          ),
                          pw.Text(
                            created,
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey600,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(content,
                          style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
    return pdf;
  }

  pw.TableRow _infoRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ),
      ],
    );
  }

  pw.Expanded _statBox(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text(label,
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey600)),
          ],
        ),
      ),
    );
  }

  String _feedbackLabel(String? f) {
    switch (f) {
      case 'easy':
        return 'Facile';
      case 'ok':
        return 'Ok';
      case 'hard':
        return 'Duro';
      default:
        return '-';
    }
  }

  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('dd/MM/yyyy').format(dt);
  }
}
