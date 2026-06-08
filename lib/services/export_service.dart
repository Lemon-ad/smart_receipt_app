import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/receipt_archive.dart';
import '../models/receipt.dart';

class ExportService {
  final _money = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ');

  Future<File> exportCsv(
    List<Receipt> receipts, {
    Map<String, ReceiptArchive> archives = const {},
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/smart_receipt_export.csv');
    final rows = [
      'Date,Merchant,Category,Type,Payment,Amount,Locked,Archived At,Last Verified,SHA256',
      ...receipts.map((r) {
        final archive = archives[r.id];
        return '${DateFormat('yyyy-MM-dd').format(r.date)},"${r.merchantName}",${r.category},${r.type},${r.paymentMethod},${r.totalAmount.toStringAsFixed(2)},${archive?.isLocked ?? false},${archive?.archivedAt.toIso8601String() ?? ''},${archive?.lastVerifiedAt?.toIso8601String() ?? ''},${archive?.sha256Hash ?? ''}';
      }),
    ];
    await file.writeAsString(rows.join('\n'));
    return file;
  }

  Future<File> exportPdf(
    List<Receipt> receipts, {
    Map<String, ReceiptArchive> archives = const {},
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/smart_receipt_report.pdf');
    final doc = pw.Document();
    final total = receipts.fold<double>(0, (sum, r) => sum + r.totalAmount);

    final headers = [
      'Date',
      'Merchant',
      'Category',
      'Type',
      'Amount',
      'Locked',
      'Hash',
    ];

    final data = receipts.map((r) {
      final archive = archives[r.id];
      return [
        DateFormat('dd MMM yyyy').format(r.date),
        r.merchantName,
        r.category,
        r.type,
        _money.format(r.totalAmount),
        archive?.isLocked == true ? 'Yes' : 'No',
        archive == null ? '-' : archive.sha256Hash,
      ];
    }).toList();

    final headerStyle = pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
      fontSize: 10,
    );
    final cellStyle = const pw.TextStyle(fontSize: 9);

    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            'Smart Receipt AI Report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Total spending: ${_money.format(total)}'),
          pw.SizedBox(height: 16),
          pw.Table(
            columnWidths: {
              0: const pw.FixedColumnWidth(58),
              1: const pw.FlexColumnWidth(2.5),
              2: const pw.FixedColumnWidth(62),
              3: const pw.FixedColumnWidth(44),
              4: const pw.FixedColumnWidth(56),
              5: const pw.FixedColumnWidth(38),
              6: const pw.FixedColumnWidth(92),
            },
            border: pw.TableBorder.all(
              color: pdf.PdfColor.fromInt(0xFFE0E0E0),
              width: 0.5,
            ),
            children: [
              pw.TableRow(
                children: headers
                    .map(
                      (h) => pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(h, style: headerStyle),
                      ),
                    )
                    .toList(),
              ),
              ...data.map(
                (row) => pw.TableRow(
                  children: row.asMap().entries.map((entry) {
                    final isHashCol = entry.key == 6;
                    return pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(
                        entry.value,
                        style: cellStyle,
                        softWrap: true,
                        maxLines: isHashCol ? 3 : null,
                        overflow: isHashCol
                            ? pw.TextOverflow.clip
                            : pw.TextOverflow.visible,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    await file.writeAsBytes(await doc.save());
    return file;
  }

  Future<void> share(File file) async {
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }
}
