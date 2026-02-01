import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:convert';
import '../widgets/design_system.dart';

class AuditLogView extends StatelessWidget {
  const AuditLogView({super.key});

  /// Esporta i dati in CSV
  Future<void> _exportCsv(List<QueryDocumentSnapshot> docs) async {
    List<List<dynamic>> rows = [];

    // Intestazioni
    rows.add([
      "Data e Ora",
      "Admin Richiedente (ID)",
      "Azione",
      "Utente Target (ID)",
      "Motivazione Legale",
      "User Agent",
    ]);

    // Dati
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['timestamp'] as Timestamp?;
      final dateStr = timestamp != null
          ? DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp.toDate())
          : 'N/A';

      rows.add([
        dateStr,
        data['requester_id'] ?? 'N/A',
        data['action'] ?? 'N/A',
        data['target_uid'] ?? 'N/A',
        data['reason'] ?? 'N/A',
        data['user_agent'] ?? 'N/A',
      ]);
    }

    // Conversione in stringa CSV
    String csvData = const ListToCsvConverter().convert(rows);

    // Download del file (Web)
    final bytes = utf8.encode(csvData);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);

    html.AnchorElement(href: url)
      ..setAttribute(
        "download",
        "audit_logs_export_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv",
      )
      ..click();

    html.Url.revokeObjectUrl(url);
  }

  Color _getActionColor(String action) {
    switch (action.toLowerCase()) {
      case 'access_user_data':
        return KyboColors.warning;
      case 'delete_user':
        return KyboColors.error;
      case 'create_user':
        return KyboColors.success;
      case 'update_user':
        return KyboColors.accent;
      default:
        return KyboColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ═══════════════════════════════════════════════════════════════════
        // HEADER
        // ═══════════════════════════════════════════════════════════════════
        _buildHeader(),

        const SizedBox(height: 24),

        // ═══════════════════════════════════════════════════════════════════
        // LOGS TABLE
        // ═══════════════════════════════════════════════════════════════════
        Expanded(child: _buildLogsTable()),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: KyboColors.roleAdmin.withOpacity(0.1),
            borderRadius: KyboBorderRadius.medium,
          ),
          child: const Icon(
            Icons.security_rounded,
            color: KyboColors.roleAdmin,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Registro Accessi",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: KyboColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Cronologia di tutte le azioni sensibili eseguite dagli amministratori",
                style: TextStyle(
                  color: KyboColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        // Export Button
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('access_logs')
              .orderBy('timestamp', descending: true)
              .limit(500)
              .snapshots(),
          builder: (context, snapshot) {
            final bool hasData =
                snapshot.hasData && snapshot.data!.docs.isNotEmpty;

            return PillButton(
              label: "Esporta CSV",
              icon: Icons.download_rounded,
              backgroundColor: KyboColors.primary,
              textColor: Colors.white,
              onPressed: hasData ? () => _exportCsv(snapshot.data!.docs) : null,
            );
          },
        ),
      ],
    );
  }

  Widget _buildLogsTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('access_logs')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: PillCard(
              padding: const EdgeInsets.all(32),
              backgroundColor: KyboColors.error.withOpacity(0.08),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: KyboColors.error,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Errore caricamento log",
                    style: TextStyle(
                      color: KyboColors.error,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${snapshot.error}",
                    style: TextStyle(
                      color: KyboColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(color: KyboColors.primary),
          );
        }

        final logs = snapshot.data!.docs;

        if (logs.isEmpty) {
          return Center(
            child: PillCard(
              padding: const EdgeInsets.all(48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: KyboColors.textMuted.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      color: KyboColors.textMuted,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Nessun log registrato",
                    style: TextStyle(
                      color: KyboColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Le azioni sensibili appariranno qui",
                    style: TextStyle(
                      color: KyboColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return PillCard(
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  KyboColors.background,
                ),
                headingRowHeight: 56,
                dataRowMinHeight: 64,
                dataRowMaxHeight: 72,
                columnSpacing: 32,
                horizontalMargin: 24,
                columns: const [
                  DataColumn(
                    label: Text(
                      "DATA/ORA",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        letterSpacing: 0.5,
                        color: KyboColors.textSecondary,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "ADMIN",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        letterSpacing: 0.5,
                        color: KyboColors.textSecondary,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "AZIONE",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        letterSpacing: 0.5,
                        color: KyboColors.textSecondary,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "TARGET UID",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        letterSpacing: 0.5,
                        color: KyboColors.textSecondary,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "MOTIVAZIONE",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        letterSpacing: 0.5,
                        color: KyboColors.textSecondary,
                      ),
                    ),
                  ),
                ],
                rows: logs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final timestamp = data['timestamp'] as Timestamp?;
                  final dateStr = timestamp != null
                      ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate())
                      : '-';
                  final action = data['action'] ?? '-';
                  final actionColor = _getActionColor(action);

                  return DataRow(
                    cells: [
                      // Date/Time
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: KyboColors.textMuted.withOpacity(0.1),
                                borderRadius: KyboBorderRadius.small,
                              ),
                              child: const Icon(
                                Icons.schedule_rounded,
                                color: KyboColors.textMuted,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                                color: KyboColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Admin ID
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: KyboColors.roleAdmin.withOpacity(0.08),
                            borderRadius: KyboBorderRadius.pill,
                          ),
                          child: Text(
                            data['requester_id'] ?? 'Unknown',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: KyboColors.roleAdmin,
                            ),
                          ),
                        ),
                      ),
                      // Action Badge
                      DataCell(
                        PillBadge(
                          label: action.toString().toUpperCase(),
                          color: actionColor,
                        ),
                      ),
                      // Target UID
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: KyboColors.background,
                            borderRadius: KyboBorderRadius.pill,
                            border: Border.all(
                              color: KyboColors.textMuted.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            data['target_uid'] ?? '-',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: KyboColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      // Reason
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 300),
                          child: Text(
                            data['reason'] ?? '-',
                            style: TextStyle(
                              fontSize: 13,
                              color: KyboColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}
