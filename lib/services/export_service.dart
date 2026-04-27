import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
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
      'Date,Merchant,Category,Type,Payment,Amount,Locked,Archived At,SHA256',
      ...receipts.map((r) {
        final archive = archives[r.id];
        return '${DateFormat('yyyy-MM-dd').format(r.date)},"${r.merchantName}",${r.category},${r.type},${r.paymentMethod},${r.totalAmount.toStringAsFixed(2)},${archive?.isLocked ?? false},${archive?.archivedAt.toIso8601String() ?? ''},${archive?.sha256Hash ?? ''}';
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
          pw.TableHelper.fromTextArray(
            headers: [
              'Date',
              'Merchant',
              'Category',
              'Type',
              'Amount',
              'Locked',
              'Hash',
            ],
            data: receipts.map((r) {
              final archive = archives[r.id];
              return [
                DateFormat('dd MMM yyyy').format(r.date),
                r.merchantName,
                r.category,
                r.type,
                _money.format(r.totalAmount),
                archive?.isLocked == true ? 'Yes' : 'No',
                archive == null
                    ? '-'
                    : '${archive.sha256Hash.substring(0, 10)}...',
              ];
            }).toList(),
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
